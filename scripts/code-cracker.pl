#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    open my $fh, "<", $fn or die "open $fn: $!";

    my $lineNum = 0;
    while (<$fh>)  {
	++$lineNum;
	my $line = $_;
	chomp($line);

	next if $line =~ /^Microsoft .* Visual /;
	next if $line =~ /^Copyright .* Microsoft/;
	next if $line =~ /^\s*$/;

	if ($line =~ /(.*?)\((\d+)(?:,(\d+))\): (\w+) (\w+):\s+(.*?)\s*$/)  {
	    my ($file, $lineNum, $columnNum, $bugGroup, $bugCode, $bugMsg)
		    = ($1, $2, $3, $4, $5, $6);
	    $columnNum = 0 unless defined $columnNum;

	    my $bugObj = $parser->NewBugInstance();
	    $bugObj->setBugLocation(1, "", $file, $lineNum, $lineNum, $columnNum, $columnNum, "", 'true', 'true');
	    $bugObj->setBugMessage($bugMsg);
	    $bugObj->setBugGroup($bugGroup);
	    $bugObj->setBugCode($bugCode);
	    $bugObj->setBugSeverity($bugGroup);
	    $bugObj->setBugLine($lineNum, $lineNum);
	    $parser->WriteBugObject($bugObj);
	}  else  {
	    print STDERR "Bad MSBuild warning line ($fn:$lineNum):\n\t$line\n"
	}

    }

    close $fh or die "close $fh: $!";
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
