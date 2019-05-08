#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $startBug = 0;
    open my $fh, "<", $fn
	    or die "unable to open the input file $fn";
    my $lineNum = 0;
    while (<$fh>)  {
	my $line = $_;
	chomp($line);

	++$lineNum;

	if ($line =~ /^\s*(.+?)\s*:\s*(\d+)\s*:\s*(\d+)\s*:\s*(.+?)\s*:\s*(.*?)\s*$/)  {
	    my ($file, $line, $col, $bugGroup, $bugMsg) = ($1, $2, $3, $4, $5);
	    my $path = $file;
	    my $bugLocId = 1;
	    my $bugCode = $bugMsg;
	    $bugCode =~ s/\s*(<.*?>|(['"`]).*?\2)\s*/ /g;
	    $bugCode =~ s/\+ \+|U\+[0-9a-f]+//ig;
	    $bugCode =~ s/^\s+//;
	    $bugCode =~ s/\s+$//;

	    my $bug = $parser->NewBugInstance();

	    $bug->setBugGroup($bugGroup);
	    $bug->setBugCode($bugCode);
	    $bug->setBugMessage($bugMsg);
	    # set $lineNum
	    $bug->setBugLocation($bugLocId, '', $path, $line, $line, $col, $col, $bugMsg, 'true', 'true');

	    $parser->WriteBugObject($bug);
	}  else  {
	    print STDERR "$0: bad line at $fn:$lineNum\n";
	}
    }
    close($fh);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
