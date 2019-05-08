#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


#Initialize the counter values
my $fileId = 0;

my %severity_hash = (
	'C' => 'Convention',
	'R' => 'Refactor',
	'W' => 'Warning',
	'E' => 'Error',
	'F' => 'Fatal',
	'I' => 'Information',
);

sub ParseFile
{
    my ($parser, $fn) = @_;

    open(my $fh, "<", $fn) or die "open $fn: $!\n";
    while (<$fh>)  {
	my ($file, $lineNum, $bugCode, $bugMsg, $bugSeverity);
	my $line = $_;
	chomp($line);
	my @tokens = split(':', $line);
	next if ($#tokens != 2);
	$file = $tokens[0];
	$lineNum = $tokens[1];
	$tokens[2] =~ /\[(.*?)\](.*)/;
	$bugCode = $1;
	$bugMsg  = $2;
	my $sever = substr($bugCode, 0, 1);
	$bugSeverity = SeverityDet($sever);
	my $bugObj = $parser->NewBugInstance();
	$bugObj->setBugLocation(1, "", $file, $lineNum, $lineNum, 0, 0, "", 'true', 'true');
	$bugObj->setBugMessage($bugMsg);
	$bugObj->setBugCode($bugCode);
	$bugObj->setBugSeverity($bugSeverity);
	$parser->WriteBugObject($bugObj);
    }
    $fh->close;
}


sub SeverityDet
{
    my ($char) = @_;

    if (exists $severity_hash{$char})  {
        return($severity_hash{$char});
    }  else  {
        die "Unknown Severity $char";
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
