#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub WriteBug
{
    my ($parser, $path, $lineNum, $columnNum, $severity, $code, $msg,
        $snippet, $url, $suggestion, $bugStartLine, $bugEndLine) = @_;

    my $bug = $parser->NewBugInstance();

    $bug->setBugLocation(1, "", $path, $lineNum, $lineNum,
			    $columnNum, $columnNum, "", 'true', 'true');
    $bug->setBugMessage($msg);
    $bug->setBugGroup($severity);
    $bug->setBugCode($code);
    $bug->setBugSuggestion($suggestion);
    $bug->setBugLine($bugStartLine, $bugEndLine);

    $parser->WriteBugObject($bug);
}


# States
# ------
#   0    expect next warning, note or warning count                -> 1, 5, 6
#   1    expect snippet                                            -> 2
#   2    expect caret                                              -> 3
#   3    expect url                                                -> 4
#   4    expect suggestion, next warning, note or warning count    -> 0
#   5    expect note or warning count                              -> 5, 6, 0
#   6    expect warning count                                      -> 6, end
#  99    error                                                     -> die


sub ParseFile
{
    my ($parser, $fn) = @_;

    use PerlIO::encoding;
    use Encode qw/:fallbacks/;
    local $PerlIO::encoding::fallback = Encode::WARN_ON_ERR;
    open my $fh, "< :encoding(UTF-8)", $fn or die open "$fn: $!";

    my ($path, $lineNum, $columnNum, $severity, $code, $msg,
	$snippet, $url, $suggestion, $bugStartLine, $bugEndLine);

    my $startWarningRe = qr/^(.*):(\d+):\s+(\w+):(?:\s+\[(.*?)\])?\s+(.*?)\s*$/;
    my $alternateWarningRe = qr/^(warning):\s+(.*)/;
    my $columnCaret = qr/^\s*\^$/;
    my $urlRe = qr/^\s+\(see (http.*)\)\s*$/;
    my $suggestionRe = qr/^\s+(Did you mean .*)$/;
    my $noteRe = qr/^Note:\s+(.*)\s*$/;
    my $countRe = qr/^(\d+)\s+(\w*?)s?\s*$/;
    my $endWarningRe = qr/$startWarningRe|$noteRe|$countRe|$alternateWarningRe/;

    my $parseErrorMsg;
    my $state = 0;
    my $fileLineNum = 1;
    my %weaknessCounts;  # number of warning entries seen

    my %numWeaknesses;   # number of warnings reported in last line of output
    my $notes = '';      # accumulated notes at end of file

    while (<$fh>)  {
	chomp;
	if ($state == 0)  {
	    # expect next warning, note or warning count

	    if (defined $bugStartLine)  {
		++$weaknessCounts{$severity};
		$bugEndLine = $fileLineNum - 1;
		if (!defined $code || $code eq '')  {
		    # synthesize code
		    if ($msg =~ /^unmappable character \(.*?\) for encoding/)  {
			$code = 'unmappable-char-for-encoding';
		    }  elsif ($msg =~ /^cannot find symbol/)  {
			$code = 'cannot-find-symbol';
		    }  elsif ($msg =~ /^as of release 9, '_' is a keyword/)  {
			$code = 'underscore-is-keyword';
		    }  elsif ($msg =~ /^unreachable catch clause/)  {
			$code = 'unreachable-catch-clause';
		    }  elsif ($msg =~ /^reference to .* is ambiguous/)  {
			$code = 'reference-is-ambiguous';
		    }  elsif ($msg =~ /^Supported source version '.*' from annotation processor '*.' less than -source/)  {
			$code = 'annotation-processor-version';
		    }  elsif ($msg =~ /^cannot access .* file .* not found/s)  {
			$code = 'file-not-found';
		    }  elsif ($msg =~ /cannot be converted/)  {
			$code = 'conversion';
		    }  elsif ($msg =~ /^method does not override or implement a method from a supertype/)  {
			$code = 'method-does-not-override-or-implement';
		    }  elsif ($msg =~ /cannot be applied to given types/)  {
			$code = 'cannot-be-applied';
		    }  elsif ($msg =~ /cannot implement.* method does not throw/)  {
			$code = 'does-not-throw';
		    }  else  {
			$code = 'uncategorized';
			print STDERR "WARNING: failed to synthesize code using uncategorized at $fn:$bugStartLine for message ($msg)\n";
		    }
		}
		WriteBug($parser, $path, $lineNum, $columnNum, $severity, $code,
			$msg, $snippet, $url, $suggestion,
			$bugStartLine, $bugEndLine);
		($path, $lineNum, $columnNum, $severity, $code, $msg, $snippet,
			$url, $suggestion, $bugStartLine, $bugEndLine) = (undef) x 11;
	    }

	    if (($path, $lineNum, $severity, $code, $msg) = ($_ =~ $startWarningRe))  {
		$bugStartLine = $fileLineNum;
		$state = 1;
	    }  elsif ($_ =~ $noteRe)  {
		$state = 5;
		redo
	    }  elsif ($_ =~ $countRe)  {
		$state = 6;
		redo
	    }  elsif ($_ =~ $alternateWarningRe)  {
		# handle rarely emitted single line error messages 'warning: <msg>'
		++$weaknessCounts{$1};
		WriteBug($parser, '', undef, undef, $1, undef,
			$2, undef, undef, undef, $fileLineNum, $fileLineNum);
	    }  else  {
		$parseErrorMsg = "expected new weakness or end of weaknesses";
		$state = 99;
		redo;
	    }
	}  elsif ($state == 1)  {
	    # expect next line as snippet

	    $snippet = $_;
	    $state = 2;
	}  elsif ($state == 2)  {
	    # expect next line as caret indicating column

	    if ($_ =~ $columnCaret)  {
		$columnNum = length $_;
		$state = 3;
	    }  else  {
		$parseErrorMsg = "expected caret column indicator line";
		$state = 99;
		redo;
	    }
	}  elsif ($state == 3)  {
	    # expect url, or a blank line or additional message text

	    if ($_ =~ $urlRe)  {
		$url = $1;
		$state = 4
	    }  elsif (/^\s*$/)  {
		# skip blank lines
	    }  elsif ($_ =~ $endWarningRe)  {
		$state = 0;
		redo;
	    }  else  {
		s/^\s*//;
		$msg .= "\n$_";
	    }
	}  elsif ($state == 4)  {
	    # expect suggestion, or end of warning indicator

	    if ($_ =~ $suggestionRe)  {
		$suggestion = $1;
		$state = 0;
	    }  elsif ($_ =~ $endWarningRe)  {
		$state = 0;
		redo;
	    }  else  {
		$parseErrorMsg = "expected suggestion line or end of warning";
		$state = 99;
		redo;
	    }
	}  elsif ($state == 5)  {
	    # expect note or warning count line

	    if ($_ =~ $noteRe)  {
		$notes .= "$1\n";
	    }  elsif ($_ =~ $countRe)  {
		$state = 6;
		redo;
	    }  elsif ($_ =~ $startWarningRe)  {
		$state = 0;
		redo;
	    }  else  {
		$parseErrorMsg = "expected note, warning count line, or new weakness";
		$state = 99;
		redo;
	    }
	}  elsif ($state == 6)  {
	    # expect warning count line or end of file

	    if (my ($count, $type) = ($_ =~ $countRe))  {
		$numWeaknesses{$type} = $1;
	    }  else  {
		$parseErrorMsg = "expected warning count line or end of file";
		$state = 99;
		redo;
	    }
	}  elsif ($state == 99)  {
	    # error state, invalid line

	    $parseErrorMsg = "ERROR parseErrorMsg not defined"
		    unless defined $parseErrorMsg;
	    die "Error parsing $fn:$fileLineNum, $parseErrorMsg, got '$_'";
	}  else  {
	    die "unknown state $state";
	}
    }  continue  {
	++$fileLineNum;
    }

    --$fileLineNum;

    # check that we are in terminal state
    # 	state 6
    # 	state 0 with no lines read (empty file)
    # 	state 5 with 0 weaknesses seen
    if (!($state == 6 || ($state == 0 && $fileLineNum == 0) || ($state == 5 && !%weaknessCounts)))  {
	die "unexpected end of file for $fn, in state $state";
    }

    # check if the number counted matched count printed at end of file
    foreach my $type (sort keys %weaknessCounts)  {
	if (!exists $numWeaknesses{$type})  {
	    my $count = $weaknessCounts{$type};
	    my @types = keys %weaknessCounts;
	    if ($type eq 'warning' && @types != 1)  {
		die "Error, saw $count $type weaknesses but no count at end of file";
	    }  else  {
		# if there is more than one type all but 'warning' types may be omitted
	    }
	}  elsif ($numWeaknesses{$type} != $weaknessCounts{$type})  {
	    die "number of warnings stated at end of file ($numWeaknesses{$type}) does not not match count seen ($weaknessCounts{$type})";
	}
    }
    foreach my $type (sort keys %numWeaknesses)  {
	if (!exists $weaknessCounts{$type})  {
	    my $count = $numWeaknesses{$type};
	    die "Error, saw no $type weaknesses but count of $count at end of file";
	}
    }

    close $fh or die "close $fh: $!";

    # print "Notes:\n$notes" unless $notes eq '';
}



my $parser = Parser->new(ParseFileProc => \&ParseFile);
