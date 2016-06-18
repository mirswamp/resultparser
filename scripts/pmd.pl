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
my $tempInputFile;

my $twig = XML::Twig->new(
	start_tag_handlers => {'file'      => \&SetFileName},
	twig_handlers      => {'violation' => \&ParseViolations}
);

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
	$tempInputFile = $inputFile;
	$buildId = $buildIds[$count];
	$count++;
	$twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


my $filePath;


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
    my $bug = GetPmdBugObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;

    $xmlWriterObj->writeBugObject($bug);
}


sub GetPmdBugObject
{
    my ($violation, $bugId, $bugXpath) = @_;

    my $adjustedFilePath = Util::AdjustPath($packageName, $cwd, $filePath);
    my $beginLine        = $violation->att('beginline');
    my $endLine          = $violation->att('endline');
    if ($beginLine > $endLine)  {
	my $t = $beginLine;
	$beginLine = $endLine;
	$endLine   = $t;
    }
    my $beginColumn     = $violation->att('begincolumn');
    my $endColumn       = $violation->att('endcolumn');
    my $rule            = $violation->att('rule');
    my $ruleset         = $violation->att('ruleset');
    my $class           = $violation->att('class');
    my $method          = $violation->att('method');
    my $priority        = $violation->att('priority');
    my $package         = $violation->att('package');
    my $externalInfoURL = $violation->att('externalInfoUrl');
    my $message         = $violation->text;
    $message =~ s/\n//g;
    my $locMsg;

    if (defined $package && defined $class)  {
	$class = $package . "." . $class;
    }
    my $bug = new bugInstance($bugId);
    ###################
    $bug->setBugLocation(
	    1, $class, $adjustedFilePath, $beginLine,
	    $endLine, $beginColumn, $endColumn, $locMsg,
	    'true', 'true'
    );
    $bug->setBugMessage($message);
    $bug->setBugBuildId($buildId);
    $bug->setClassAttribs($class, $adjustedFilePath, $beginLine, $endLine, "");
    $bug->setBugSeverity($priority);
    $bug->setBugGroup($ruleset);
    $bug->setBugCode($rule);
    $bug->setBugPath($bugXpath . "[" . $fileId . "]" . "/violation[" . $bugId . "]");
    $bug->setBugBuildId($buildId);
    $bug->setBugReportPath($tempInputFile);
    $bug->setBugMethod(1, $class, $method, 'true') if defined $method;
    $bug->setBugPackage($package);
    $bug->setURLText($externalInfoURL);
    return $bug;
}
