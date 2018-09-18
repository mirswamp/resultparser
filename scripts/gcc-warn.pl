#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use bugInstance;
use Util;
# use warnings FATAL => 'all';

binmode STDERR, ":encoding(UTF-8)" or die "binmode STDERR :encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)" or die "binmode STDOUT :encoding(UTF-8)";

my $openSingleQuote = qr/['\x{2018}\x{201b}]/;
my $closeSingleQuote = qr/['\x{2019}\x{201b}]/;
my $openDoubleQuote = qr/["\x{201c}\x{201f}]/;
my $closeDoubleQuote = qr/["\x{201d}]/;


my $violationId = 0;
my $bugId       = 0;
my $locationId  = 0;
my $fileId     = 0;

my $prev_line        = "";
my $traceStartLine = 1;
my $methodId;
my $currentLineNum;
my $fnFile = '';
my $function = '';
my $line;
my $message;
my $prevMsg;
my $prevBugGroup;
my $prev_fn;

my $bug;

sub ParseFile
{
    my ($parser, $fn) = @_;

    $prevMsg         = "";
    $prevBugGroup   = "";
    $prev_fn          = "";
    $prev_line        = "";
    $traceStartLine = 1;
    $locationId       = 0;
    $methodId         = 0;

    open(my $input, "< :encoding(UTF-8)", "$fn") or die "open $fn; $!";
    my $fn_flag = -1;
LINE:
    while (my $line = <$input>)  {
	chomp($line);
	$currentLineNum = $.;
	if ($line eq $prev_line)  {
	    next LINE;
	}  else  {
	    $prev_line = $line;
	}
	my $valid = ValidateLine($line, $fn, $currentLineNum);
	if ($valid eq "function")  {
	    my ($fn, $class, $func, $type, $instantionTypes) = ParseFunctionLine($line);
	    $fnFile = $fn;
	    $function = $func;
	    $fn_flag  = 1;
	}  elsif ($valid ne "invalid")  {
	    # --- FIXME: why is function and fnFile cleared
	    # if ($fn_flag == 1)  {
		# $fn_flag = -1;
	    # }  else  {
		# $function = "";
		# $fnFile  = "";
	    # }
	    ParseLine($parser, $currentLineNum, $line, $function, $fnFile, $fn);
	}  else  {
	    print "WARNING: unhandled-line: $fn:$currentLineNum:  $line\n" if $line !~ /^\s/;	#jk
	}
    }
    if (defined $bug)  {
	$parser->WriteBugObject($bug);
	undef $bug;
    }
}


sub ParseLine
{
    my ($parser, $bugReportLine, $line, $function, $fnFile, $fn) = @_;

    if ($line =~ /^(\S.*?):(\d+)(?:\:(\d+)):\s+(.*):\s+(.*?)\s*$/)  {
	my ($file, $lineNum, $colNum, $bugGroup, $message) = ($1, $2, $3, $4, $5);
	$colNum = 0 unless defined $colNum;
	RegisterBug($parser, $bugReportLine, $function, $fnFile, $file, $lineNum,
	                $colNum, $bugGroup, $message);
    }  else  {
	print STDERR "WARNING $fn:$bugReportLine: ParseLine bad line: $line\n";
    }
}


sub RegisterBugpath
{
    my ($bugReportLine) = @_;

    my ($bugLineStart, $bugLineEnd);
    if ($bugId > 0)  {
	if ($traceStartLine eq $bugReportLine - 1)  {
	    $bugLineStart = $traceStartLine;
	    $bugLineEnd   = $traceStartLine;
	}  else  {
	    $bugLineStart = $traceStartLine;
	    $bugLineEnd   = $bugReportLine - 1;
	}
	$bug->setBugLine($bugLineStart, $bugLineEnd);
	$traceStartLine = $bugReportLine;
    }
}


sub RegisterBug
{
    my ($parser, $bugReportLine, $function, $fnFile, $file, $lineNum, $colNum,
	    $bugGroup, $message) = @_;

    if ($bugGroup eq "note" and $bugId > 0)  {
	return unless defined $bug;

	$bug->setBugLocation(
		++$locationId, "", $file, $lineNum,
		$lineNum, $colNum, 0,     $message,
		"false", "true"
	);
	$prevMsg       = $message;
	$prevBugGroup = $bugGroup;
	$prev_fn        = $function;
	$parser->WriteBugObject($bug);
	undef $bug;
	return;
    }
    if ($fnFile ne $file || $prevMsg ne $message || $prevBugGroup ne $bugGroup
	    || $prev_fn ne $function || $bugGroup =~ /^(warning|error)$/)  {
	    # why 99?  || $prev_fn ne $function || $locationId > 99)  {
	if (defined $bug)  {
	    $parser->WriteBugObject($bug);
	    undef $bug;
	}
	$bugId++;
	$bug = $parser->NewBugInstance();
	RegisterBugpath($bugReportLine);
	undef $bugReportLine;
	$methodId   = 0;
	$locationId = 0;

	if ($function ne '')  {
	    $bug->setBugMethod(++$methodId, "", $function, "true");
	}
	$bug->setBugGroup($bugGroup);
	ParseMessage($message);
    }

    $bug->setBugLocation(
	    ++$locationId, "", $file, $lineNum,
	    $lineNum, $colNum, 0,     "",
	    "true", "true"
    );
    $prevMsg       = $message;
    $prevBugGroup = $bugGroup;
    $prev_fn        = $function;
}


sub ParseMessage
{
    my ($message) = @_;

    my $code;

    if ($message =~ /(.*)\[(.*)\]$/)  {
	$message = $1;
	$code = $2;
    }  else  {
	$code = $message;
	$code =~ s/$openSingleQuote|$closeSingleQuote/'/;
	$code =~ s/$openDoubleQuote|$closeDoubleQuote/"/;
	$code =~ s/(?: \d+)? of '.*?'//g;
	$code =~ s/^".*?" //;
	$code =~ s/ ".*?"//g;
	$code =~ s/(?: (?:to|from))? '.*?'//g;
	$code =~ s/^(ignoring return value, declared with attribute).*/$1/;
	$code =~ s/^(#(?:warning|error)) .*/$1/;
	$code =~ s/cc1: warning: .*: No such file or directory/-Wmissing-include-dirs/;
	$code =~ s/  +/ /g;
    }

    if ((defined $message) && ($message ne ''))  {
	$bug->setBugMessage($message);
    }
    if ((defined $code) && ($code ne ''))  {
	$bug->setBugCode($code);
    }
}


sub ValidateLine
{
    my ($line, $fn, $lineNum) = @_;

    my $r;

    if ($line =~ /\S.*: +warning *:.*/i)  {
	$r = "warning";
    }  elsif ($line =~ /\S.*: +error *:.*/i)  {
	$r = "error";
    }  elsif ($line =~ /\S.*: +note *:.*/i)  {
	$r = "note";
    }  elsif ($line =~ /^(?:\S.*: )?At (?:top level|global scope):/i)  {
	$r = "function";
    }  elsif ($line =~ /^\S.*: *In .*(function|constructor|destructor|instantiation).*$/)  {
	$r = "function";
    }  elsif ($line =~ /^\S.*: +In /i)  {
	# check for missing types of "In * ..." lines
	die "ERROR: $fn:$lineNum unknown 'In line': $line";
    }  else  {
	$r = "invalid";
    }

    #printf "%-8s %s\n", $r, $line;
    return $r;

    # <FILE>: In instantiation of 'C<T>':
    #   instantiated from '...'
    #   instantiated from here
    # In function <FUNC>,
    # In file included from <FILE>:<LINE>:<COL>
    #                  from <FILE>:<LINE>:<COL>
    #
    #  extern char *getenv()		[ one space before line
    #               ^
    #   required from '...'
    #   required from here
    #   recursively required from '...'
    #   [ skipping <N> instantiation contexts, ... ]
    #   compilation terminated
    #   <FILE>:<LINE>: fatal error:
    #
    #   isn't nuumeric in numeric gt
}


sub ParseFunctionLine
{
    my ($line) = @_;
    my ($filename, $class, $function, $type, $instantionTypes);

    if ($line =~ /(.*):\s+In (.*?) $openSingleQuote(.*?)$closeSingleQuote/)  {
	$filename = $1;
	$type = $2;
	my $signature = $3;
	$type =~ s/ of$//;
	if ($signature =~ s/ (\[with .*\])//)  {
	    $instantionTypes = $1;
	}
	$function = $signature;
	# FIXME: should parse into class, function, param types
    }  elsif ($line =~/(?:(.*): )?At (top level|global scope):/)  {
	# FIXME: filename here should be irrelevant
	$filename = $1;
	$filename = '' unless defined $filename;
	$type = 'top-level';
	$function = '';
    }

    my @r = ($filename, $class, $function, $type, $instantionTypes);

    return @r;
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
