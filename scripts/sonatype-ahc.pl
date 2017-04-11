#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;
use JSON;


sub ParseFile
{
    my ($parser, $fn) = @_;

    if (!exists $parser->{resultParserMsg})  {
	my $toolType = $parser->{ps}{toolType};
	my $msg = "No SCARF file created, $toolType produces no result data.\n\n";
	$parser->{resultParserMsg} .= $msg;
	print STDERR $msg;
    }

    my $totalViols = 0;

    my $jsonData = Util::ReadFile($fn);
    my $json = JSON->new->utf8->decode($jsonData);

    die "input file $fn: missing {summary}"
	    unless exists $json->{summary};
    die "input file $fn: missing {summary}{policyViolations}"
	    unless exists $json->{summary}{policyViolations};
    my $viols = $json->{summary}{policyViolations};
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
