#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);

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
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion,
	@inputFiles) = Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

my $twig = XML::Twig->new(
	twig_roots         => {'file'  => 1},
	start_tag_handlers => {'file'  => \&SetFileName},
	twig_handlers      => {'error' => \&ParseViolations}
);

#Initialize the counter values
my $bugId = 0;
my $fileId = 0;
my $filePath = "";
my $count = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $tempInputFile;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId()-1);
}


sub SetFileName
{
    my ($tree, $element) = @_;

    $filePath = $element->att('name');
    $element->purge() if defined $element;
    $fileId++;
}


sub ParseViolations
{
    my ($tree, $elem) = @_;

    my $bugXpath = $elem->path();

    my $bug = GetCheckstyleBugObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;

    $xmlWriterObj->writeBugObject($bug);
}


sub GetCheckstyleBugObject  {
    my ($violation, $bugId, $bugXpath) = @_;

    my $adjustedFilePath = Util::AdjustPath($packageName, $cwd, $filePath);
    my $beginLine = $violation->att('line');
    my $endLine = $beginLine;
    my $beginColumn = (defined $violation->att('column')) ? $violation->att('column') : 0;
    my $endColumn = $beginColumn;
    my $sourceRule = $violation->att('source');
    my $priority = $violation->att('severity');
    my $message = $violation->att('message');
    my $bug = new bugInstance($bugId);

    $bug->setBugLocation(1, "", $adjustedFilePath, $beginLine, $endLine,
	    $beginColumn, 0, "", 'true', 'true');
    $bug->setBugMessage($message);
    $bug->setBugSeverity($priority);
    $bug->setBugGroup($priority);
    $bug->setBugCode($sourceRule);
    $bug->setBugPath($bugXpath . "[" . $fileId . "]" . "/error[" . $bugId . "]");
    $bug->setBugBuildId($buildId);
    $bug->setBugReportPath("$tempInputFile");
    return $bug;
}
