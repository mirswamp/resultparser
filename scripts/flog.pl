#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use 5.010;

my (
    $inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version
);

GetOptions(
	"input_dir=s"   => \$inputDir,
	"output_file=s"  => \$outputFile,
	"tool_name=s"    => \$toolName,
	"summary_file=s" => \$summaryFile,
	"weakness_count_file=s" => \$weaknessCountFile,
	"help" => \$help,
	"version" => \$version
    ) or die("Error");

Util::Usage() if defined $help;
Util::Version() if defined $version;

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $count = 0;
my $tempInputFile;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    open my $file, "$inputDir/$inputFile" or die ("Unable to open file $inputDir/$inputFile");
    state $counter = 0;
    my %h;

    while (my $line = <$file>)  {
    	if ($line =~ /flog total/)  {
            my @fields = split /:/, $line;
            $h{'summary'}{'total'} = $fields[0];
            $h{'summary'}{'location'} = $.;
            $xmlWriterObj->writeMetricObject($h{'summary'});
        }  elsif ($line =~ /method average/)  {
            my @fields = split /:/, $line;
            $h{'summary'}{'average'} = $fields[0];
            $h{'summary'}{'location'} = $.;
            $xmlWriterObj->writeMetricObject($h{'summary'});
        }  elsif ($line =~/^$/)  {
            #Ignore Empty Lines
        }  elsif ($line =~ /none/)  {
            $h{'none'}{'location'} = $.;
            my @fields = split /:/, $line;
            $h{'none'}{'CCN'} = $fields[0];
            $xmlWriterObj->writeMetricObject($h{'none'});
        }  else  {
            $line =~ /(\d+\.\d+):\s+([A-Za-z:]+)\#(\w+).*:(\d+)/;
            $h{$3}{'CCN'} = $1;
            $h{$3}{'line'} = $4;
            $h{$3}{'location'} = $.;
            $xmlWriterObj->writeMetricObject($h{$3});
        }
        $counter++;
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId()-1);
}
