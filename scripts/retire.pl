#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile);

GetOptions(
	"input_dir=s"           => \$inputDir,
	"output_file=s"         => \$outputFile,
	"tool_name=s"           => \$toolName,
	"summary_file=s"        => \$summaryFile,
	"weakness_count_file=s" => \$weaknessCountFile
    ) or die("Error");

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $count = 0;

foreach my $inputFile (@inputFiles)  {
    $buildId = $buildIds[$count];
    $count++;
    my $jsonData;
    {
	open FILE, "$inputDir/$inputFile"
	  or die "open $inputDir/$inputFile.: $!";
	local $/;
	$jsonData = <FILE>;
	close FILE or die "close $inputDir/$inputFile: $!";
    }

    my @data = @{decode_json($json)};
    foreach my $arr (@data)  {
	my $bug = new bugInstance($bugId);
	my $jt         = $arr;
	my $file       = $jt->{"file"};
	my @results    = $jt->{"results"};
	my $r          = $results[0][0];
	my $component  = $r->{"component"};
	my $detection  = $r->{"detection"};
	my $version    = $r->{"version"};
	my @vulns      = $r->{"vulnerabilities"}[0];
	foreach my $v (@vulns)  {
	    my $sev         = $v->{"severity"};
	    my $identifiers = $v->{"identifiers"};
	    if (exists $identifiers->{"summary"})  {
		my $summary = $identifiers->{"summary"};
	    }
	    if (exists $identifiers->{"bug"})  {
		my $bug = $identifiers->{"bug"};
	    }
	    if (exists $identifiers->{"CVE"})  {
		my @cve = $identifiers->{"CVE"};
		my $cv  = $cve[0][0];
	    }
	}

	#FIXME: Decide BugObject Population
	my $bug = new bugInstance($xmlWriterObj->getBugId());
	$xmlWriterObj->writeBugObject($bug);
    }

    $xmlWriterObj->writeSummary();
    $xmlWriterObj->addEndTag();

}

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}
