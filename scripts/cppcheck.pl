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
my $count = 0;
my $tempInputFile;

my $twig = XML::Twig->new(
	twig_roots    => {'errors' => 1},
	twig_handlers => {'error'  => \&parseViolations}
);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId        = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub parseViolations {
    my ($tree, $elem) = @_;

    my $bugXpath = $elem->path();
    my $file      = "";
    my $lineno    = "";
    getCppCheckBugObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;
    $tree->purge() if defined $tree;
}


sub getCppCheckBugObject  {
    my ($violation, $bugId, $bugXpath) = @_;

    my $bugCode            = $violation->att('id');
    my $bugSeverity        = $violation->att('severity');
    my $bugMsg         = $violation->att('msg');
    my $bug_message_verbose = $violation->att('verbose');
    my $bug_inconclusive    = $violation->att('inconclusive');
    my $bug_cwe             = $violation->att('cwe');

    my $bug  = new bugInstance($bugId);
    my $locationId = 0;

    foreach my $error_element ($violation->children)  {
	my $tag    = $error_element->tag;
	my $file   = "";
	my $lineno = "";
	if ($tag eq 'location')  {
	    $file = Util::AdjustPath($packageName, $cwd, $error_element->att('file'));
	    $lineno = $error_element->att('line');
	    $locationId++;
	    $bug->setBugLocation($locationId, "",
		    Util::AdjustPath($packageName, $cwd, $file),
		    $lineno, $lineno, "0", "0", $bugMsg, 'true', 'true');
	}
    }

    $bug->setBugMessage($bug_message_verbose);
    $bug->setBugGroup($bugSeverity);
    $bug->setBugCode($bugCode);
    $bug->setBugPath($bugXpath . "[" . $bugId . "]");
    $bug->setBugBuildId($buildId);
    $bug->setBugInconclusive($bug_inconclusive) if defined $bug_inconclusive;
    $bug->setCweId($bug_cwe) if defined $bug_cwe;
    $bug->setBugReportPath($tempInputFile);
    $xmlWriterObj->writeBugObject($bug);
    undef $bug;
}
