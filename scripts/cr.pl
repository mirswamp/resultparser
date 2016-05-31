#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile);

GetOptions(
	"input_dir=s"    => \$inputDir,
	"output_file=s"  => \$outputFile,
	"tool_name=s"    => \$toolName,
	"summary_file=s" => \$summaryFile
) or die("Error");

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

my $twig = XML::Twig->new(
	twig_roots    => {'module'   => 1},
	twig_handlers => {'function' => \&parseMetric}
);

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $buildId = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub parseMetric {
    my ($tree, $elem) = @_;

    my $bugXpath = $elem->path();

    my $bug = GetXMLObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;

    $xmlWriterObj->writeBugObject($bug);
}


sub GetXMLObject  {
    my ($elem, $bugId, $bugXpath) = @_;

    my $adjustedFilePath = Util::AdjustPath($packageName, $cwd, $filePath);

    # Ignoring Halstead Metrics
    my $funcName = $elem->att('name');
    my $line     = $elem->first_child('line')->text;
    my $ccn      = $elem->first_child('cyclomatic')->text;
    my $cd       = $elem->first_child('cyclomatic-density')->text;
    my $params   = $elem->first_child('parameters')->text;
    my $sloc     = $elem->first_child('sloc');
    my $psloc    = $sloc->first_child('physical')->text;
    my $lsloc    = $sloc->first_child('logical')->text;

    # TODO: Populate Metric Object

    $bug->setBugMessage($message);
    $bug->setBugCode($sourceRule);
    return $bug;
}
