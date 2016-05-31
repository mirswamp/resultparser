#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
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

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

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
    my $json_obj = JSON->new->utf8->decode($jsonData);

    foreach my $warning (@{$json_obj->{"vulnerabilities"}})  {
	$bugId = $xmlWriterObj->getBugId();
	my $bug = new bugInstance($bugId);
	my $name       = $warning->{"name"};
	my $cvss_score = $warning->{"cvss_score"};
	if (defined $cvss_score && $cvss_score ne "null")  {
	    $bug->setCWEInfo($cvss_score);
	}
	$bug->setBugCode($name);
	$bug->setBugMessage($warning->{"message"});
	$bug->setBugSeverity($warning->{"severity"});
	$bug->setBugRank($warning->{"priority"});
	$bug->setBugSuggestion($warning->{"remediation"});
	$bug->setBugReportPath($tempInputFile);
	my $cveLink = $warning->{"cve_link"};

	if (defined $cveLink && $cveLink ne "null")  {
	    $bug->setURLText($cveLink);
	}  elsif ($name =~ m/^\s*CVE.*$/i)  {
	    $bug->setURLText("https://cve.mitre.org/cgi-bin/cvename.cgi?name=" . $name);
	}

	#TODO : Add links to OSDVB and OWASP codes
	$xmlWriterObj->writeBugObject($bug);
    }
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}
