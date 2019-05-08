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


my %msgMap = (
    'Comparing'			=> 'UselessEqualityCheck',
    'unused'			=> 'UnusedVariable',
    'undefined method'		=> 'UndefinedMethod',
    'undefined'			=> 'UndefinedVariable',
    'shadowing outer'		=> 'ShadowingVariables',
    'can only be used inside'	=> 'LoopKeywords',
    'wrong number of argument'	=> 'ArgumentAmount',
);


my $msgKeys = join '|', keys %msgMap;
my $msgRe = qr/^($msgKeys)/i;


sub ParseFile
{
    my ($parser, $fn) = @_;

    open(my $fh, "<", $fn) or die "open $fn: $!";
    while (<$fh>)  {
	my $curr_line   = $_;
	my @tokens      = split(/:/, $curr_line, 5);
	my $file        = $tokens[0];
	my $severity    = $severity_hash{$tokens[1]};
	my $line        = $tokens[2];
	my $column      = $tokens[3];
	my $bugMsg = $tokens[4];
	$bugMsg =~ s/^\s*//;
	chomp($bugMsg);
	my $bugCode   = BugCode($bugMsg);
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
    close $fh;
}


sub BugCode
{
    my ($bugMsg) = @_;

    if ($bugMsg =~ /($msgRe)/)  {
	$bugMsg = $msgMap{$1}
    }

    return $bugMsg;
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
