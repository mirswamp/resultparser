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
    open my $fh, "<", $fn or die "open $fn: $!";

    my $lineNum = 0;
    while (<$fh>)  {
	my $line = $_;
	chomp($line);

	++$lineNum;

	if ($line =~ /^\s*(.+?)\s*:\s*(\d+)\s*:\s*(\d+)\s*:\s*(.+?)\s*:\s*(.*?)\s*$/)  {
	    my ($file, $lineNum, $col, $bugGroup, $bugMsg) = ($1, $2, $3, $4, $5);
	    my $path = $file;
	    my $bugLocId = 1;
	    my $bugCode = $bugMsg;

	    # synthesize bugCode from message
	    $bugCode =~ s/(\s|^)\(value=".*?"\)(\s|$)/$1$2/g;
	    $bugCode =~ s/(\s|^)(['"]).*?\2(\s|$)/$1$3/g;
	    $bugCode =~ s/(\s|^)\(char\. code U\+[0-9a-fA-F]{4}\)(\s|$)/$1$2/g;
	    $bugCode =~ s/(\s|^)\<\w[-:.\w]*?\>(\s|$)/$1start tag$2/g;
	    $bugCode =~ s/(\s|^)\<\/\w[-:.\w]*?\>(\s|$)/$1end tag$2/g;
	    $bugCode =~ s/(\s|^)\<\w[-:.\w]*?\/\>(\s|$)/$1empty tag$2/g;
	    $bugCode =~ s/start tag elements?/element/g;
	    $bugCode =~ s/(\+\s)+//g;
	    $bugCode =~ s/\s+/ /g;
	    $bugCode =~ s/^\s//;
	    $bugCode =~ s/\s$//;
	    $bugCode =~ s/^(replacing unexpected )[-:.\w]+? (with )/$1$2/;
	    $bugCode =~ s/^(entity doesn't end in)/$1 semicolon/;

	    my $bug = $parser->NewBugInstance();

	    $bug->setBugGroup($bugGroup);
	    $bug->setBugCode($bugCode);
	    $bug->setBugMessage($bugMsg);
	    # set $lineNum
	    $bug->setBugLocation($bugLocId, '', $path, $lineNum, $lineNum, $col, $col, $bugMsg, 'true', 'true');

	    $parser->WriteBugObject($bug);
	}  else  {
	    print STDERR "$0: skipping bad line ($line) at $fn:$lineNum\n";
	}
    }
    close $fh or die "close $fn: $!";
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
