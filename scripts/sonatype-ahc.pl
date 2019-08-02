#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    if (!exists $parser->{resultParserMsg})  {
	my $toolName = $parser->{ps}{tool_name};
	my $msg = "No SCARF file created, $toolName produces no result data.\n\n";
	$parser->{resultParserMsg} .= $msg;
	print STDERR $msg;
    }

    my $totalViols = 0;

    my $jsonObject = Util::ReadJsonFile($fn);

    die "input file $fn: missing {summary}"
	    unless exists $jsonObject->{summary};
    die "input file $fn: missing {summary}{policyViolations}"
	    unless exists $jsonObject->{summary}{policyViolations};
    my $viols = $jsonObject->{summary}{policyViolations};
    for my $type (qw/critical severe moderate/)  {
	die "input file $fn: missing {summary}{policyViolations}{$type}"
		unless exists $viols->{$type};
	my $violCount = $viols->{$type};
	$totalViols += $violCount;
	$parser->{resultParserMsg} .= "$type violations: $violCount\n";
    }

    $parser->{resultParserState} = 'SKIP';
    $parser->{weaknessCount} += $totalViols
}



my $parser = Parser->new(ParseFileProc => \&ParseFile, NoScarfFile => 1);
