#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;
#use Data::Dumper;

binmode STDERR, ":encoding(UTF-8)" or die "binmode STDERR :encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)" or die "binmode STDOUT :encoding(UTF-8)";

my $openSingleQuote = qr/['\x{2018}\x{201b}]/;
my $closeSingleQuote = qr/['\x{2019}\x{201b}]/;
my $openDoubleQuote = qr/["\x{201c}\x{201f}]/;
my $closeDoubleQuote = qr/["\x{201d}]/;
my $openQuote = qr/$openSingleQuote|$openDoubleQuote/;
my $closeQuote = qr/$closeSingleQuote|$closeDoubleQuote/;
my $quotedValueRe = qr/$openQuote(.*?)$closeQuote/;

my $sourceLocRe = qr/(\S*?)(?::(\d+)(?::(\d+))?)?/;

my $atTopLevelRe = qr/^(?:(.*?): )?At (top level|global scope):$/;
my $inFunctionRe = qr/^(?:(.*?): )?In ((?:(?:static )?member )?function|(?:copy )?constructor|destructor) $quotedValueRe([,:])$/;
my $inlinedFromRe = qr/^\s{3,}inlined from $quotedValueRe(?: at $sourceLocRe)?([:,])$/;
my $instantiationValue = qr/$openQuote((?:(class|struct) )?(.*?)(?:\((.*?)\))?(?:\s+\[with (.*)\])?)$closeQuote/;
my $inInstantiationRe = qr/^$sourceLocRe: In instantiation of $instantiationValue([:,])$/;
my $requiredFromRe = qr/^$sourceLocRe:\s{3,}(recursively )?(?:required|instantiated) (?:from|by substitution of) (?:(here)|$instantiationValue)$/;
my $synthesizedMethodRequiredFromRe = qr/synthesized method $quotedValueRe first required here/;
my $skippingInstantiationRe = qr/^$sourceLocRe:\s{3,}\[\s+skipping (\d+) instantiation contexts.*\]$/;
my $weaknessLineRe = qr/^$sourceLocRe:(?: (warning|note|error|fatal error):\s(\s*)(.*?)(?:\s*\[([^[]*)\])?)?$/;
my $inFileIncludedFromRe = qr/^In file included from (.*?):(\d+)(?::(\d+))?([:,])$/;
my $moreInFileIncludedFromRe = qr/^\s+from (.*?):(\d+)(?::(\d+))?([:,])$/;
my $contextLineRe = qr/^ (.*)$/;
my $caretLineRe = qr/^ (\s*\~*\s*\^?\s*\~*)\s*$/;
my $compilationTerminatedRe = qr/^compilation terminated\.$/;


# curBug = {
#	firstLineNum	=>
#	lastLineNum	=>
#	function	=> {
#		id		=>
#		file		=>
#		functionName	=>
#		type		=>
#		inlinedFroms	=> [
#				{
#					functionName	=>
#					file		=>
#		 			startLine	=>
#					startColumn	=>
#				},
#				...
#		]
#		synthesized
#		instantiatedFroms  => [
#				{
#					file		=>
#					startLine	=>
#					startColumn	=>
#					instantiationOf	=>
#					functionName	=>
#					functionArgs	=>
#					templateArgs	=>
#					recursive	=>
#					skipCount	=>
#				},
#				...
#			]
#		},
#	}
#	locations	=> [
#		{
#			file		=> 
#			startLine	=> 
#			startColumn	=>
#			severity	=>
#			message		=> 
#			code		=> 
#			caretLine	=>
#			snippetLine	=>
#			includedFroms	=> [
#				{
#					file		=>
#					startLine	=> 
#					startColumn	=>
#				},
#				...
#			],
#			function	=>  { <see-above> },
#		},
#		...
#	    ]
#	}



# mapping from warning code to regular expression of gcc message
my %codeToMessageRe =  (
    '#pragma-message'			=> qr/^\#pragma message:/,
    '#warning'				=> qr/^\#warning/,
    '-Warray-bounds'			=> qr/^offset outside bounds of/,
    '-Wcomments'			=> qr/^"\/\*" within comment/,
    '-Wdiscarded-qualifiers'		=> qr/discards( $quotedValueRe)? qualifiers? from/,
    '-Wendif-labels'			=> qr/^extra tokens at end of #endif directive$/,
    '-Wfree-nonheap-object'		=> qr/^attempt to free a non-heap object$/,
    '-Wincompatible-pointer-types'	=> qr/from incompatible pointer type$/,
    '-Wint-to-pointer-cast'		=> qr/makes pointer from integer without a cast$/,
    '-Wmissing-include-dirs'		=> qr/^(.*:\s+)?No such file or directory$/m,
    '-Wno-return-local-addr'		=> qr/^function returns address of local variable$/,
    '-Woverflow'			=> qr/^integer constant is too large for $quotedValueRe type/,
    '-Wshift-count-overflow'		=> qr/^(left|right) shift count >= width of type$/,
    '-Wstringop-overflow'		=> qr/^call to __builtin\S* will always overflow destination buffer$/,
    '-Wunused-macros'			=> qr/^macro $quotedValueRe is not used$/m,
    '-Wvariadic-macros'			=> qr/^anonymous variadic macros were introduced in C99$/m,
    'C++-comments-incompatible'		=> qr/^C\+\+ style comments are incompatible with C90$/m,
    'call-warning'			=> qr/^call to $quotedValueRe declared with attribute warning:/,
    'enum-nonenum'			=> qr/^enumeral and non-enumeral type in conditional expression$/,
    'ignored-return-value'		=> qr/^ignoring return value of $quotedValueRe, declared with attribute warn_unused_result$/,
    'initializing-argument'		=> qr/^initializing argument \d+ of $quotedValueRe$/,
    'macro-whitespace-C90'		=> qr/^ISO C99 requires whitespace after the macro name$/,
    'redefined-macro'			=> qr/^$quotedValueRe redefined$/m,
    'syntax'				=> qr/^expected identifier or $openQuote\($closeQuote before ${openQuote}__extension__$closeQuote$/,
    'undefined-macro'			=> qr/^$quotedValueRe is not defined$/m,
    'const-unsigned-only-in-C90'	=> qr/^this decimal constant is unsigned only in ISO C90$/,
    'uncomputable-at-load-time'		=> qr/^initializer element is not computable at load time$/,
);


sub GetGroupCodeFromLocation
{
    my ($loc) = @_;

    my ($group, $code, $message) = @{$loc}{qw/severity code message/};

    $message =~ s/\n.*//s;						# discard all but first line

    undef $code if defined $code && $code eq 'enabled by default';	# synthesize if 'enabled by default'

    warn "GetGroupCodeFromLocation called with severity 'note'" if $group eq 'note';

    if (defined $code)  {
	if ($code !~ /^-W/ && $code ne '-pedantic')  {
	    print STDERR "Warning:  unknown code ($code) [not -W* or -pedantic]\n";
	}
    }  else  {
	 keys %codeToMessageRe;
	 while (my ($c, $re) = each %codeToMessageRe)  { 
	     if ($message =~ /$re/)  { 
		 $code = $c; 
		 last; 
	     } 
	 } 

	 if (defined $code)  {
	    if ($code eq '-wmissing-include-dirs' && $loc->{file} eq 'cc1'
			&& !defined $loc->{startline})  {
		$loc->{file} = undef;
	    }
	 }  else  {
	    # synthesize code from the message

	    $code = $message;
	    $code =~ s/$quotedValueRe/?/g;		# replace quoted items with ?
	    $code =~ s/(^|\s)\d+($|\s)/$1?$2/g;		# replace numbers with ?
	    print STDERR "Warning:  no code specified and unrecognized message,  using ($code) for message ($message)";
	    # warn dumper($loc) . "\n";
	 }
    }

    my @a = ($group, $code);
    return @a;
}


#sub DebugOut
#{
#    #printf @_;
#}


sub GetWeaknessMessage
{
    my ($parser, $w) = @_;

    my $message = $w->{locations}[0]{message};

    return $message;
}


sub GetLocMessage
{
    my ($parser, $loc, $prevLoc) = @_;

    my $message = $loc->{message};

    my $function = $loc->{function};
    my ($functionId, $prevFunctionId) = (0, 0);
    $functionId = $function->{id} if defined $function;
    $prevFunctionId = $prevLoc->{function}{id} if defined $prevLoc && defined $prevLoc->{function};
 
    if (defined $function && $functionId != $prevFunctionId)  {
	if ($prevFunctionId != 0)  {
	    my ($type, $functionName) = @{$function}{qw/type functionName/};
	    if (defined $functionName)  {
		$type = '' unless defined $type;
		$message .= "\n\nIn $type '$functionName'.";
	    }  else  {
		$message .= "\n\nAt global scope.";
	    }
	}

	my $inlinedFroms = $function->{inlinedFroms};
	if (@$inlinedFroms)  {
	    $message .= "\n\nInlined:";
	    foreach my $inlinedFrom (@$inlinedFroms)  {
		my ($functionName, $line, $column) = @{$inlinedFrom}{qw/functionName startline startColumn/};
		my $file = $parser->AdjustPath($inlinedFrom->{file});

		$message .= "\n";
		$message .= " from '$functionName'" if defined $functionName;
		if (defined $file)  {
		    $message .= " at $file";
		    $message .= ":$line" if defined $line;
		    $message .= ":$column" if defined $column;
		}
	    }
	}

	my $instantiatedFroms = $function->{instantiatedFroms};
	if (@$instantiatedFroms)  {
	    $message .= "\n\nInstantiated:";

	    foreach my $i (@$instantiatedFroms)  {
		$message .= "\n  ";

		my $skipCount = $i->{skipCount};
		if ($skipCount == 0)  {
		    my ($instantiationOf, $line, $column, $recursive)
			    = @{$i}{qw/instantiationOf startLine startColumn recursive/};
		    my $file = $parser->AdjustPath($i->{file});
		    if (defined $instantiationOf)  {
			$instantiationOf = "'$instantiationOf'";
		    }  else  {
			$instantiationOf = 'here';
		    }
		    $message .= "recursively "	if $recursive;
		    $message .= "from $instantiationOf at $file";
		    $message .= ":$line"		if defined $line;
		    $message .= ":$column"		if defined $column;
		}  else  {
		    $message .= "[skipping $skipCount instantiation contexts]";
		}
	    }
	}
    }

    if (@{$loc->{includedFroms}})  {
	$message .= "\n\nIncluded:";
	foreach my $i (@{$loc->{includedFroms}})  {
	    my $file = $parser->AdjustPath($i->{file});
	    $message .= "\n  from $file";
	    $message .= ":" . $i->{startLine} if defined $i->{startLine};
	    $message .= ":" . $i->{startColumn} if defined $i->{startColumn};
	}
    }

    return $message;
}


sub GetLocLineColumn
{
    my ($loc) = @_;
    my ($startLine, $startColumn, $caretLine) = @{$loc}{qw/startLine startColumn caretLine/};
    my $endLine = $startLine;
    my $endColumn = $startColumn;

    if (defined $startLine && defined $startColumn && defined $caretLine)  {
	if (my ($col1, $lines, $col2) = ($caretLine =~ /\^([^\n]*~)?(?:(.*)([^\n]*~))?/s))  {
	    $endColumn += length($col1) if defined $col1;
	    $endLine += ($lines =~ tr/\n//) if defined $lines;
	    $endColumn = length($col2) if defined $col2;
	}
    }

    my @a = ($startLine, $endLine, $startColumn, $endColumn);

    return @a;
}


sub ProcessWeakness
{
    my ($parser, $weakness, $lastLineNum) = @_;
    if (exists $weakness->{locations})  {
	$weakness->{lastLineNum} = $lastLineNum;
	# DebugOut "%s\n", Dumper($weakness);

	my $bug = $parser->NewBugInstance();
	my $locations = $weakness->{locations};
	my ($group, $code) = GetGroupCodeFromLocation($locations->[0]);
	my $message = GetWeaknessMessage($parser, $weakness);

	$bug->setBugGroup($group);
	$bug->setBugCode($code);
	$bug->setBugMessage($message);
	$bug->setBugLine($weakness->{firstLineNum}, $weakness->{lastLineNum});
	$bug->setBugMethod(0, undef, $locations->[0]{functionName}, 'true')
		if defined $locations->[0]{functionName};

	my $locationId = 0;
	my $primary = 'true';
	my $prevLoc;
	foreach my $loc (@{$weakness->{locations}})  {
	    my $file = $loc->{file};
	    my $locMessage = GetLocMessage($parser, $loc, $prevLoc);
	    my ($startLine, $endLine, $startColumn, $endColumn) = GetLocLineColumn($loc);
	    $bug->setBugLocation($locationId, "", $file, $startLine, $endLine,
				    $startColumn, $endColumn, $locMessage, $primary);
	    $primary = 'false';
	    $prevLoc = $loc;
	}

	$parser->WriteBugObject($bug);
    }

    %$weakness = ();
}


sub MakeWeaknessLocation
{
    my ($file, $startLine, $startColumn, $severity, $message, $code,
	    $includedFroms, $includedFromFiles, $curFunction) = @_;

    my %h = (
		file		=> $file,
		startLine	=> $startLine,
		startColumn	=> $startColumn,
		severity	=> $severity,
		message		=> $message,
		code		=> $code,
		includedFroms	=> [],
		function	=> $curFunction,
	    );
    
    if (exists $includedFromFiles->{$file})  {
	foreach my $r (@$includedFroms)  {
	    if ($file eq $r->{file})  {
		@{$h{includedFroms}} = ()
	    }  else  {
		push @{$h{includedFroms}}, $r;
	    }
	}
    }

    return \%h;
}


my $functionId = 0;

sub NewCurFunction
{
    my ($file, $functionName, $type) = @_;

    my %h = (
		id			=> $functionId++,
		file			=> $file,
		functionName		=> $functionName,
		type			=> $type,
		instantiatedFroms	=> [],
		inlinedFroms		=> [],
	    );

    return \%h;
}


sub AddInstantiation
{
    my ($curFunction, $file, $line, $column, $instantiationOf, $classKeyword,
	$functionName, $functionArgs, $templateArgs, $recursive, $here, $skipCount) = @_;
    
    $skipCount = 0 unless defined $skipCount;
    undef $functionName if defined $classKeyword || !defined $functionArgs;

    push @{$curFunction->{instantiatedFroms}}, {
	    file		=> $file,
	    startline		=> $line,
	    startColumn		=> $column,
	    instantiationOf	=> $instantiationOf,
	    functionName	=> $functionName,
	    functionArgs	=> $functionArgs,
	    templateArgs	=> $templateArgs,
	    recursive		=> $recursive,
	    skipCount		=> $skipCount,
	};
}


sub CompareWithUndefined
{
    my ($a, $b) = @_;

    if (defined $a)  {
	return 0 unless defined $b;
	return $a eq $b;
    }  else  {
	return !defined $b;
    }
}


sub ShouldAddLocToWeakness
{
    my ($weakness, $loc) = @_;

    return 0 unless exists $weakness->{locations} && @{$weakness->{locations}} > 0;

    my $wLoc = $weakness->{locations}[-1];

    foreach my $a (qw/file startLine startColumn severity code/)  {
	return 0 unless CompareWithUndefined($wLoc->{$a}, $loc->{$a});
    }

    if (!CompareWithUndefined($wLoc->{code}, $loc->{code}))  {
	return 0 unless !defined $loc->{code} && CompareWithUndefined($loc->{message}, '(this will be reported only once per input file)');
    }

    return 1;
}


sub AddLocToWeakness
{
    my ($weakness, $loc) = @_;

    my $wLoc = $weakness->{locations}[-1];

    $wLoc->{message} .= "\n" . $loc->{message};
}


# my $sep = '';

sub ParseFile
{
    my ($parser, $fn) = @_;

    # DebugOut '%s', $sep . '-' x 70 . "\n$fn\n" . '-' x 70 . "\n";
    # $sep = "\n\n\n";

    open my $fh, "< :encoding(UTF-8)", $fn or die "open $fn; $!";

    my $curSourceFile;
    my $curFunction;
    my $includedFile;
    my @includedFroms;
    my %includedFromFiles;
    my ($expectingSnippet, $expectingCaret, $expectingMoreIncludedFrom,
	$expectingInstantiatedFrom, $expectingInlinedFrom);
    my $lineNum = 0;
    my $lastWeaknessLineNum = 0;
    my $weaknessStartLineNum = 1;
    my %curWeakness = ();

    # regular expression value variables
    my ($file, $line, $column, $severity, $extraSpaces, $msg, $code,
	$recursive, $skipCount, $instantiationOf, $here,
	$classKeyword, $functionArgs, $templateArgs,
	$functionType, $functionName, $endPunctuation);

    while (<$fh>)  {
	++$lineNum;
	s/\b\s*$//			# delete whitespace include \n and \r at eof of line
		|| s/[\n\r]*$//;	#   unless all whitespace, then just \n and \r

	if ($expectingSnippet)  {
	    $expectingSnippet = 0;
	    if (($line) = /$contextLineRe/)  {
		# DebugOut "%4d %-12s %s\n", $lineNum, "SNIP", $_;
		my $locData = $curWeakness{locations}[-1];
		if (!exists $locData->{snippetLine})  {
		    $locData->{snippetLine} = $line;
		}  else  {
		    $locData->{snippetLine} .= "\n$line";
		}
		$lastWeaknessLineNum = $lineNum;
		$expectingCaret = 1;
		next;
	    }
	}

	if ($expectingCaret)  {
	    $expectingCaret = 0;
	    if (($line) = /$caretLineRe/)  {
		# DebugOut "%4d %-12s %s\n", $lineNum, "CARET", $_;
		my $locData = $curWeakness{locations}[-1];
		if (!exists $locData->{caretLine})  {
		    $locData->{caretLine} = $line;
		}  else  {
		    $locData->{caretLine} .= "\n$line";
		}
		$lastWeaknessLineNum = $lineNum;
		$expectingSnippet = 1;
		next;
	    }
	}

	if ($expectingMoreIncludedFrom)  {
	    if (($file, $line, $column, $endPunctuation) = /$moreInFileIncludedFromRe/)  {
		# DebugOut "%4d %-12s %s\n", $lineNum, "INFILE+", $_;
		push @includedFroms, {file => $file, startLine => $line, startColumn => $column};
		++$includedFromFiles{$file};
		$expectingMoreIncludedFrom = $endPunctuation eq ',';
		next;
	    }  else  {
		$expectingMoreIncludedFrom = 0;
	    }
	}

	if ($expectingInstantiatedFrom)  {
	    if (($file, $line, $column, $recursive, $here, $instantiationOf, $classKeyword,
			$functionName, $functionArgs, $templateArgs) = /$requiredFromRe/)  {
		# DebugOut "%4d %-12s %s\n", $lineNum, "INSTAN+", $_;
		AddInstantiation($curFunction, $file, $line, $column, $instantiationOf, $classKeyword, 
			$functionName, $functionArgs, $templateArgs, $recursive, $here, undef);
		$expectingInstantiatedFrom = !defined $here;
		next;
	    }  elsif (($file, $line, $column, $skipCount) = /$skippingInstantiationRe/)  {
		# DebugOut "%4d %-12s %s\n", $lineNum, "INSTANSKIP", $_;
		AddInstantiation($curFunction, $file, $line, $column, undef, undef, 
			undef, undef, undef, undef, undef, $skipCount);
		next;
	    }  else  {
		$expectingInstantiatedFrom = 0;
	    }
	}

	if ($expectingInlinedFrom)  {
	    if (($functionName, $file, $line, $column, $endPunctuation) = /$inlinedFromRe/)  {
		push @{$curFunction->{inlinedFroms}}, {
							functionName	=> $functionName,
							file		=> $file,
							startLine	=> $line,
							startColumn	=> $column,
						    };
		$expectingInlinedFrom = $endPunctuation eq ',';
		next;
	    }
	}

	if (($file, $line, $column, $severity, $extraSpaces, $msg, $code) = /$weaknessLineRe/)  {
	    $expectingSnippet = 1;
	    $expectingInstantiatedFrom = 1;
	    if (!defined $includedFile && @includedFroms)  {
		$includedFile = $file;
		$includedFromFiles{$file} = 1;
	    }
	    my $sourceFile = $file;
	    $sourceFile = $includedFroms[-1]{file} if @includedFroms && exists $includedFroms[-1]{file};
	    if (!defined $curSourceFile || $curSourceFile ne $sourceFile)  {
		$curSourceFile = $sourceFile;
		undef $curFunction;
	    }

	    $severity = 'note' unless defined $severity;

	    my $loc = MakeWeaknessLocation($file, $line, $column, $severity, $msg, $code,
					    \@includedFroms, \%includedFromFiles, $curFunction);

	    if (ShouldAddLocToWeakness(\%curWeakness, $loc))  {
		AddLocToWeakness(\%curWeakness, $loc);
		my $mark = $extraSpaces ne '' ? '+' : '*';
		# DebugOut "%4d %-12s %s\n", $lineNum, " " . uc($severity) . $mark, $_;
	    }  else  {
		if (defined $severity && $severity ne 'note')  {
		    if ($severity ne 'warning' || defined $code
				|| $msg ne 'this is the location of the previous definition')  {
			ProcessWeakness($parser, \%curWeakness, $lastWeaknessLineNum);
			%curWeakness = (
						function	=> $curFunction,
						firstLineNum	=> $lastWeaknessLineNum + 1,
					    );
		    }
		}
		# DebugOut "%4d %-12s %s\n", $lineNum, " " . uc($severity), $_;

		$lastWeaknessLineNum = $lineNum;
		push @{$curWeakness{locations}}, $loc;
	    }
	}  elsif (($file, $line, $column, $endPunctuation) = /$inFileIncludedFromRe/)  {
	    # DebugOut "%4d %-12s %s\n", $lineNum, "INFILE", $_;
	    @includedFroms = ({file => $file, startLine => $line, startColumn => $column});
	    %includedFromFiles = ($file => 1);
	    undef $includedFile;
	    $expectingMoreIncludedFrom = $endPunctuation eq ',';
	}  elsif (($file) = /$atTopLevelRe/)  {
	    # DebugOut "%4d %-12s %s\n", $lineNum, "AT_TOP", $_;
	    $curFunction = NewCurFunction($file, undef, undef);
	}  elsif ($_ eq '')  {
	    # skip
	}  elsif (($file, $functionType, $functionName, $endPunctuation) = /$inFunctionRe/)  {
	    # DebugOut "%4d %-12s %s\n", $lineNum, "IN_FNCT", $_;
	    $curFunction = NewCurFunction($file, $functionName, 'instantiation of');
	    $expectingInlinedFrom = $endPunctuation eq ',';
	    $expectingInstantiatedFrom = 1;
	}  elsif (($file, $line, $column, $instantiationOf, $classKeyword, $functionName, $functionArgs,
		    $templateArgs, $endPunctuation) = /$inInstantiationRe/)  {
	    # DebugOut "%4d %-12s %s\n", $lineNum, "INSTAN", $_;
	    undef $functionName if defined $classKeyword || !defined $functionArgs;
	    $curFunction = NewCurFunction($file, $functionName, 'instantiation of');
	    AddInstantiation($curFunction, $file, $line, $column, $instantiationOf, $classKeyword, 
		    $functionName, $functionArgs, $templateArgs, undef, undef, undef);
	    $expectingInlinedFrom = $endPunctuation eq ',';
	    $expectingInstantiatedFrom = 1;
	}  elsif (/$compilationTerminatedRe/)  {
	    # DebugOut "%4d %-12s %s\n", $lineNum, "TERMINATED", $_;
	    # ignore this line
	}  else  {
	    # DebugOut "%4d %-12s %s\n", $lineNum, "UNKNOWN", $_;
	    # $| = 1;
	    print STDERR  "Error:  skipping unknown line at $fn:$lineNum; ($_)";
	}
    }
    close $fh or die "close $fn: $!";

    ProcessWeakness($parser, \%curWeakness, $lastWeaknessLineNum);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
