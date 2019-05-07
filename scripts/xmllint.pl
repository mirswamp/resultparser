#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;



sub ParseFile
{
    my ($parser, $fn) = @_;

    open(my $fh, "<", $fn) or die "open $fn: $!";
    while (<$fh>)  {
	chomp;
	if (/^(.+):(\d+):\s+(.*?)\s*:\s+(.*)\s*/)  {
	    my ($file, $lineNum, $group, $msg) = ($1, $2, $3, $4);

	    my $bug = $parser->NewBugInstance();
	    $bug->setBugLocation(
		    1, "", $file, $lineNum,
		    $lineNum, undef, undef, "",
		    'true', 'true'
	    );
	    #FIXME: Decide on BugCode for xmllint
	    $bug->setBugGroup($group);
	    $bug->setBugCode($group);
	    $bug->setBugMessage($msg);
	    $parser->WriteBugObject($bug);
	}
    }
    $fh->close();
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
