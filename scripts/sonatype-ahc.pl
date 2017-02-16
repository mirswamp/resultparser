#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use Util;
use JSON;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);

GetOptions(
	"input_dir=s"           => \$inputDir,
	"output_file=s"         => \$outputFile,
	"tool_name=s"           => \$toolName,
	"summary_file=s"        => \$summaryFile,
	"weakness_count_file=s" => \$weaknessCountFile,
	"help"                  => \$help,
	"version"               => \$version
    ) or die("Error");

Util::Usage()   if defined $help;
Util::Version() if defined $version;

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;
my $tempInputFile;

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;
my $totalViols = 0;

my $msg = "No SCARF file created, $toolName produces no result data.\n\n";

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    my $jsonData = "";
    $buildId = $buildIds[$count];
    $count++;
    {
	open FILE, "$inputDir/$inputFile"
		or die "open $inputDir/$inputFile : $!";
	local $/;
	$jsonData = <FILE>;
	close FILE or die "close $inputDir/$inputFile : $!";
    }
    my $json = JSON->new->utf8->decode($jsonData);

    die "input file $inputFile: missing {summary}"
	    unless exists $json->{summary};
    die "input file $inputFile: missing {summary}{policyViolations}"
	    unless exists $json->{summary}{policyViolations};
    my $viols = $json->{summary}{policyViolations};
    for my $type (qw/critical severe moderate/)  {
	die "input file $inputFile: missing {summary}{policyViolations}{$type}"
		unless exists $viols->{$type};
	my $violCount = $viols->{$type};
	$totalViols += $violCount;
	$msg .= "$type violations: $violCount\n";
    }
}

print $msg;

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $totalViols, 'SKIP', $msg);
}
