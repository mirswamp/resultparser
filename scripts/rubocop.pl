#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

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

my %severity_hash = (
	R => 'refactor',
	C => 'convention',
	W => 'warning',
	E => 'error',
	F => 'fatal'
);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $count = 0;
my $tempInputFile;

foreach my $inputFile (@inputFiles)  {
    $buildId = $buildIds[$count];
    $tempInputFile = $inputFile;
    $count++;
    open(my $fh, "<", "$inputDir/$inputFile")
	    or die "Could not open the input file $!";
    while (<$fh>)  {
	my $curr_line = $_;
	chomp($curr_line);
	my ($file, $line, $column, $severity, $bugCode, $bugMsg) =
		$curr_line =~
			/(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*:\s*(.*)/;

	$file = Util::AdjustPath($packageName, $cwd, $file);
	$severity = $severity_hash{$severity};

	my $bugObj = new bugInstance($xmlWriterObj->getBugId());
	$bugObj->setBugLocation(
		1, "", $file, $line, $line, $column,
		$column, "", 'true', 'true'
	);
	$bugObj->setBugMessage($bugMsg);
	$bugObj->setBugSeverity($severity);
	$bugObj->setBugCode($bugCode);
	$bugObj->setBugBuildId($buildId);
	$bugObj->setBugReportPath($tempInputFile);
	$xmlWriterObj->writeBugObject($bugObj);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
