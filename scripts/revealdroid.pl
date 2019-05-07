#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    if (!-f $fn)  {
	die "ERROR: Revealdroid assessment run did not complete. $fn not found\n";
    }

    my %data;
    my $msg;

    open my $fh, "<", $fn or die "open $fn: $!";
    while (<$fh>)  {
	$msg .= $_;
	chomp;
	if (/^((?:Reputation|Family)(?: Confidence)?):\s*(.*?)\s*$/)  {
	    die "Duplicate keys found: $1" if exists $data{$1};
	    $data{$1} = $2;
	}
    }
    close $fh;

    if (($data{Reputation} eq "Benign") && ($data{'Reputation Confidence'} == 1))  {
	return;
    }

    #Create Bug Object#
    my $file_data;
    my $bug = $parser->NewBugInstance();
    $bug->setBugMessage($msg);
    $bug->setBugGroup($data{Reputation});
    if (exists $data{Family})  {
	$bug->setBugCode($data{Family})
    }  else  {
	$bug->setBugCode('not-confident')
    }
    $parser->WriteBugObject($bug);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
