#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use JSON;
use xmlWriterObject;
use Util;
use 5.010;

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

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $count = 0;
my counter = 0;

foreach my $inputFile (@inputFiles)  {
    $buildId = $buildIds[$count];
    $count++;
    my $json;
    {
	local $/;
	open my $fh, "<", "$inputDir/$inputFile";
	$json = <$fh>;
	close $fh;
    }
    my $data    = decode_json($json);
    my $k       = (keys %{$data})[0];
    my @records = @{$data->{$k}};
    foreach my $v (@records)  {
	my %h;
	$h{$counter}{'name'}       = $v->{"name"};
	$h{$counter}{'col_offset'} = $v->{"col_offset"};
	$h{$counter}{'rank'}       = $v->{"rank"};
	$h{$counter}{'classname'}  = $v->{"classname"};
	$h{$counter}{'complexity'} = $v->{"complexity"};
	$h{$counter}{'lineno'}     = $v->{"lineno"};
	$h{$counter}{'endline'}    = $v->{"endline"};
	$h{$counter}{'type'}       = $v->{"type"};
	$xmlWriterObj->writeMetricObject($h{$counter});
	$counter++;
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
