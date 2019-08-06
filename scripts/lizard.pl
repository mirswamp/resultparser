#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;
use 5.012;

sub ParseFile
{
    my ($parser, $fn) = @_;

    my %h;
    my %seenNames;	# seenNames{sourceFile}{uniqueFuncName}
	#   $seenNames{file}{name} = ' @lines' (no duplicates)
	#   $seenNames{file}{name} = ''       (duplicates, add @lines)
	#   $seenNames{file}{name@Lines} = '' (no duplicates)
	#   $seenNames{file}{name@Lines} = N  (N duplicates, add #N)

    use PerlIO::encoding;
    use Encode qw/:fallbacks/;
    local $PerlIO::encoding::fallback = Encode::WARN_ON_ERR;
    open my $file, '< :encoding(UTF-8)', $fn or die "open $fn: $!";

    # verify and skip 3 header lines
    my $line = <$file>;
    chomp $line;
    if (!defined $line)  {
	die "Error:  $fn:  missing header line 1 in output file";
    }  elsif ($line !~ /^=*$/)  {
	die "Error:  $fn:$.:  malformed header, expected all '=', got '$line'";
    }

    $line = <$file>;
    chomp $line;
    if (!defined $line)  {
	die "Error:  $fn:  missing header line 2 in output file";
    }  elsif ($line !~ /^\s+NLOC\s+CCN\s+token\s+PARAM\s+length\s+location/)  {
	die "Error:  $fn:$.:  malformed header, expected NLOC CCN token PARAM length location, got $line";
    }

    $line = <$file>;
    chomp $line;
    if (!defined $line)  {
	die "Error:  $fn:  missing header line 3 in output file";
    }  elsif ($line !~ /^-*$/)  {
	die "Error:  $fn:$.:  malformed header, expected all '-', got '$line'";
    }

    my $lineBeginRe = qr/^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)/s;
    my $lineRe = qr/$lineBeginRe@(\d+)-(\d+)@(.*)$/s;

    LINE: while (my $line = <$file>)  {
	# skip empty lines
	next if $line =~ /^\s*$/;

	# these lines indicate end of metric data
	last if $line =~ /^[-=]+/;
	last if $line =~ /\d+\s+file.*analyzed\./;

	chomp $line;

	# lizard can put linefeed chars in the function name, try to handle this
	if ($line !~ $lineRe)  {
	    my $badLineNum = $.;
	    while ($line =~ $lineBeginRe)  {
		# concatenate lines until valid or next line is valid on its own
		my $nextLine = <$file>;
		last unless defined $nextLine;
		if ($nextLine =~ $lineRe || $nextLine =~ /^[-=]+/)  {
		    # let outer loop handle the valid next line,
		    # discard invalid lines
		    my $endBadLineNum = $. - 1;
		    $badLineNum .= "-$endBadLineNum"
			    unless $badLineNum == $endBadLineNum;
		    $line =~ s/\n/\\n/g;
		    warn "Error:  $fn:$badLineNum:  invalid line discarding:  $line";
		    $line = $nextLine;
		    redo LINE;
		}
		$line .= "\n$nextLine";
		redo LINE if $line =~ $lineRe
	    }
	    $badLineNum .= "-$." unless $badLineNum == $.;
	    $line =~ s/\n/\\n/g;
	    warn "Error:  $fn:$badLineNum:  invalid line discarding:  $line";
	    next;
	}

	my ($codeLines, $ccn, $numTokens, $numParams, $totalLines,
		$fullFuncName, $startLine, $endLine, $sourceFile)
		= ($1, $2, $3, $4, $5, $6, $7, $8, $9);

	my ($className, $funcName);
	if ($fullFuncName =~ /^\w+(::\w+)*$/)  {
	    ($className, $funcName) = ($fullFuncName =~ /^(?:(.*)::)?(.*)$/);
	}  else  {
	    $funcName = $fullFuncName;
	}
	$className = '' unless defined $className;

	my %metrics = (
	    token		=> $numTokens,
	    ccn			=> $ccn,
	    params		=> $numParams,
	    'code-lines'	=> $codeLines,
	    'total-lines'	=> $totalLines,
	);

	my %location = (
	    startline		=> $startLine,
	    endline		=> $endLine,
	);

	my %functStat = (
	    class		=> $className,
	    class		=> $className,
	    function		=> $funcName,
	    file		=> $sourceFile,
	    metrics		=> \%metrics,
	    location		=> \%location,
	);

	if (!exists $h{$sourceFile})  {
	    $h{$sourceFile} = {
		'file-stat'	=> {},
		'func-stat'	=> {},
	    };
	}

	my $fileFuncStats = $h{$sourceFile}{'func-stat'};
	my $uniqueName = $fullFuncName;

	# find a unique name:
	#   method name is unchanged, maybe it should be or add new field
	if (exists $seenNames{$sourceFile}{$uniqueName})  {
	    # function name seen already, add " @lines" suffix
	    my $seenFileNames = $seenNames{$sourceFile};
	    my $seenLoc = $seenFileNames->{$uniqueName};
	    if ($seenLoc =~ /^\s*@/)  {
		# first duplicate of this function name in this file
		# move old name to new
		my $newUniqueName = "$uniqueName$seenLoc";
		$fileFuncStats->{$newUniqueName} = $fileFuncStats->{$uniqueName};
		delete $fileFuncStats->{$uniqueName};
		$seenFileNames->{$uniqueName} = '';
		$seenFileNames->{$newUniqueName} = '';
	    }

	    $uniqueName .= " \@$startLine-$endLine";

	    if (exists $seenFileNames->{$uniqueName})  {
		# function name with these lines seen already, add " #N" suffix
		$seenLoc = $seenFileNames->{$uniqueName};
		if ($seenLoc eq '')  {
		    # first duplicate of this (function name, loc) in this file
		    # move old name to new
		    my $num = 1;	# starting unique number suffix
		    my $newUniqueName = "$uniqueName #$num";
		    $seenFileNames->{$uniqueName} = $num;
		    $fileFuncStats->{$newUniqueName} = $fileFuncStats->{$uniqueName};
		    delete $fileFuncStats->{$uniqueName};
		}

		my $num = ++$seenFileNames->{$uniqueName};
		$uniqueName .= " #$num";
	    }  else  {
		$seenFileNames->{$uniqueName} = '';
	    }
	}  else  {
	    $seenNames{$sourceFile}{$uniqueName} = " \@$startLine-$endLine";
	}

	# duplicate could have happened if earlier functions had weird names
	die "Error:  $fn:$.:  Uniqueness algorithm fail: $uniqueName"
		if exists $fileFuncStats->{$uniqueName};

	$fileFuncStats->{$uniqueName} = \%functStat;
    }

    $parser->WriteMetrics(\%h);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
