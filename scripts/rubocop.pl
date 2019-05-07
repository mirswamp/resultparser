#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;

my %severity_hash = (
	R => 'Refactor',
	C => 'Convention',
	W => 'Warning',
	E => 'Error',
	F => 'Fatal',
	I => 'Information'
);


sub ParseFile
{
    my ($parser, $fn) = @_;

    open(my $fh, "<", $fn) or die "open $fn: $!";
    while (<$fh>)  {
	my $curr_line = $_;
	chomp($curr_line);
	my ($file, $line, $column, $severity, $bugCode, $bugMsg) =
		$curr_line =~
			/(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*(?::\s*(.*?))?\s*:\s*(.*)/;

	$file = $file;
	if (exists $severity_hash{$severity})  {
	    $severity = $severity_hash{$severity};
	}  else  {
	    $severity = "Unknown";
	}
	$bugCode = $severity unless defined $bugCode;

	my $bug = $parser->NewBugInstance();
	$bug->setBugLocation(
		1, "", $file, $line, $line, $column,
		$column, "", 'true', 'true'
	);
	$bug->setBugMessage($bugMsg);
	$bug->setBugSeverity($severity);
	$bug->setBugGroup($severity);
	$bug->setBugCode($bugCode);
	$parser->WriteBugObject($bug);
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
