#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile,
	$help, $version);

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
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion,
	@inputFiles) = Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

my $count = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $tempInputFile;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    my $jsonData;
    $buildId = $buildIds[$count];
    $count++;
    {
	open FILE, "$inputDir/$inputFile"
		or die "open $inputDir/$inputFile.: $!";
	local $/;
	$jsonData = <FILE>;
	close FILE or die "close $inputDir/$inputFile: $!";
    }

    my $jsonObject = JSON->new->utf8->decode($jsonData);
    my $appPath = $jsonObject->{"scan_info"}->{"app_path"};
    
    $appPath =~ s/^\Q$packageName\E\///;
    foreach my $warning (@{$jsonObject->{"warnings"}})  {
	my $file = $appPath."/".$warning->{"file"};

	my $bug = new bugInstance($xmlWriterObj->getBugId());

	if (defined $warning->{"line"})  {
	    my $line = $warning->{"line"};
	    $bug->setBugLocation(1, "", $file, $line, $line, 0, 0, "", "true", "true");
	} else {
	    $bug->setBugLocation(1, "", $file, 0, 0, 0, 0, "", "true", "true");
	}

	if (defined $warning->{"location"})  {
	    if ($warning->{"location"}{"type"} eq "method")  {
		my $class  = $warning->{"location"}{"class"};
		my $method = $warning->{"location"}{"method"};
		#FIXME change to \Q$class\E
		$method =~ s/$class.//;
		$bug->setBugMethod(1, $class, $method, "true");
		$bug->setClassName($warning->{"location"}{"class"});
	    }
	}

	$bug->setBugMessage(sprintf("%s (%s)", $warning->{"message"}, $warning->{"link"}));
	$bug->setBugCode($warning->{"warning_type"});
	$bug->setBugSeverity($warning->{"confidence"});
	$bug->setBugWarningCode($warning->{"warning_code"});
	$bug->setBugToolSpecificCode($warning->{"code"});
	$bug->setBugReportPath($tempInputFile);
	$xmlWriterObj->writeBugObject($bug);
    }
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}
