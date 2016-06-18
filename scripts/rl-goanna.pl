#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
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

my $twig = XML::Twig->new(
	twig_roots    => {'results'         => 1},
	twig_handlers => {'results/warning' => \&ParseWarning}
);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $locationId;
my $tempInputFile;
my $fileId = 0;
my $count   = 0;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $fileId++;
    $buildId = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub ParseWarning
{
    my ($tree, $elem) = @_;

    my $method     = $elem->first_child('method')->text;
    my $filePath   = $elem->first_child('absFile')->text;
    $filePath   = Util::AdjustPath($packageName, $cwd, $filePath);
    my $bugCode    = $elem->first_child('checkName')->text;
    my $beginLine  = $elem->first_child('lineNo')->text;
    my $endLine    = $beginLine;
    my $beginCol   = $elem->first_child('column')->text;
    my $endCol     = $elem->first_child('column')->text;
    my $bugMsg     = $elem->first_child('message')->text;
    my $severity   = $elem->first_child('severity')->text;
    my $locationId = 0;

    my $bug = new bugInstance($xmlWriterObj->getBugId());
    $bug->setBugLocation(
	    1, "", $filePath, $beginLine, $endLine, $beginCol,
	    $endCol, "", 'true', 'true'
    );
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($severity);
    $bug->setBugCode($bugCode);
    $locationId++;
    $bug->setBugBuildId($buildId);
    $bug->setBugMethod($locationId, "", "", $method, 1);
    $bug->setBugReportPath($tempInputFile);
    my $xpath_bug_id = $xmlWriterObj->getBugId() - 1;
    $bug->setBugPath($elem->path() . "[" 
	      . $fileId . "]"
	      . "/warning["
	      . $xpath_bug_id
	      . "]");
    my $trace_block = $elem->first_child('trace');

    foreach my $traceblock_tr ($trace_block->children('traceBlock'))  {
	my $file   = $traceblock_tr->att('file');
	my $method = $traceblock_tr->att('method');
	$bug = traceline($traceblock_tr, $file, $bug);
    }
    $xmlWriterObj->writeBugObject($bug);
}


sub traceline
{
    my ($elem, $file, $bug) = @_;

    my $method = "";
    foreach my $traceline ($elem->children('traceLine'))  {
	$locationId++;
	$bug->setBugLocation(
		$locationId, $method, $file,
		$traceline->att('line'),
		$traceline->att('line'),
		0, 0, $traceline->att('text'),
		'false', 'true'
	    );
    }
    return $bug;
}
