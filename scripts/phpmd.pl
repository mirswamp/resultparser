#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);
my $violationId = 0;
my $bugId       = 0;
my $fileId     = 0;

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
my $filePath;

my $twig = XML::Twig->new(
	twig_roots         => {'file'  => 1},
	start_tag_handlers => {'file'  => \&setFileName},
	twig_handlers      => {'violation' => \&parseViolations}
);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $tempInputFile;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId()-1);
}


sub setFileName
{
    my ($tree, $elem) = @_;

    $filePath = Util::AdjustPath($packageName, $cwd, $elem->att('name'));
    $elem->purge() if defined $elem;
    $fileId++;
}


sub parseViolations
{
    my ($tree, $elem) = @_;

    my $bugXpath = $elem->path();

    my $bug = getPHPMDBugObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;
    $xmlWriterObj->writeBugObject($bug);
}


sub getPHPMDBugObject
{
    my ($violation, $bugId, $bugXpath) = @_;

    my $beginLine	= $violation->att('beginline');
    my $endLine		= $violation->att('endline');
    my $beginColumn	= (defined $violation->att('column')) ? $violation->att('column') : 0;
    my $endColumn	= $beginColumn;
    my $priority	= $violation->att('priority');
    my $message		= $violation->text;
    $message		=~ s/^\s+|\s+$//g;
    my $bugCode		= $violation->att('rule');
    my $bugGroup	= $violation->att('ruleset');
    my $package		= $violation->att('package');
    my $class		= $violation->att('class');
    my $infoUrl		= $violation->att('externalInfoUrl');
    $message .= " (see $infoUrl)" if defined $infoUrl;
    my $bug   = new bugInstance($bugId);

    $bug->setBugLocation(1, $class, $filePath, $beginLine, $endLine,
	    $beginColumn, $endColumn, "", 'true', 'true');
    $bug->setBugMessage($message);
    $bug->setBugSeverity($priority);
    $bug->setBugGroup($bugGroup);
    $bug->setBugCode($bugCode);
    $bug->setBugPath($bugXpath . "[" . $fileId . "]" . "/error[" . $bugId . "]");
    $bug->setBugBuildId($buildId);
    $bug->setClassName($class) if defined $class;
    $bug->setBugReportPath($tempInputFile);

    return $bug;
}
