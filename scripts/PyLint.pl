#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;

my %severity_hash = (
    C => 'Convention',
    R => 'Refactor',
    W => 'Warning',
    E => 'Error',
    F => 'Fatal',
    I => 'Information'
);


sub ParseFile
{
    my ($parser, $fn) = @_;

    open(my $fh, "<", $fn) or die "open $fn: $!";
    my $msg = " ";
    my $tempBug;
    while (<$fh>)  {
	my ($file, $lineNum, $bugCode, $bugExample, $bugMsg);
	my $line = $_;
	chomp($line);
	if ($line =~ /^Report$/)  {
	    last;
	}

	## checking for comment line or empty line
	if (!($line =~ /^\*{13}/) && !($line =~ /^$/))  {
	    ($file, $lineNum, $bugCode, $bugExample, $bugMsg) = ParseLine($line);
	    if ($file eq "invalid_line")  {
		$msg = $msg . "\n" . $line;
		print "\n*** invalid line";
		if (defined $tempBug)  {
		    $tempBug->setBugMessage($msg);
		}
	    }  else  {
		my $bug = $parser->NewBugInstance();
		if (defined $tempBug)  {
		    $parser->WriteBugObject($tempBug);
		}
		my $bugSeverity = SeverityDet(substr($bugCode, 0, 1));
		$bug->setBugLocation(1, "", $file, $lineNum, $lineNum, 0, 0, "", 'true', 'true');
		$msg = $bug->setBugMessage($bugMsg);
		$bug->setBugSeverity($bugSeverity);
		$bug->setBugGroup($bugSeverity);
		$bug->setBugCode($bugCode);
		$tempBug = $bug;
	    }
	}
    }
    if (defined $tempBug)  {
	$parser->WriteBugObject($tempBug);
    }
}


sub ParseLine
{
    my ($line) = @_;

    my @tokens1 = split(":", $line);
    if ($#tokens1 < 2)  {
	return "invalid_line";
    }
    my $file      = $tokens1[0];
    my $lineNum  = $tokens1[1];
    my $line_trim = $tokens1[2];

     ## code to join rest of the message (this is done to recover from unwanted split due to : present in message)
    for (my $i = 3 ; $i <= $#tokens1 ; $i++)  {
	$line_trim = $line_trim . ":" . $tokens1[$i];
    }
    $line_trim =~ /\[(.*?)\](.*)/;
    my $bugDescription = $1;
    my $bugMsg = $2;
    $bugMsg =~ s/^\s+//;
    $bugMsg =~ s/\s+$//;
    my ($bugCode, $bugExample);
    ($bugCode, $bugExample) = split(", ", $bugDescription);
    $bugCode =~ s/^\s+//;
    $bugCode =~ s/\s+$//;
    $bugExample   =~ s/^\s+//;
    $bugExample   =~ s/\s+$//;
    return ($file, $lineNum, $bugCode, $bugExample, $bugMsg);
}


sub SeverityDet
{
    my ($char) = @_;

    if (exists $severity_hash{$char})  {
	return ($severity_hash{$char});
    }  else  {
	die "Unknown Severity $char";
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
