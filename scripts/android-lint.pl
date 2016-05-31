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

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my $twig = XML::Twig->new(
	twig_roots    => {'issues' => 1},
	twig_handlers => {'issue'  => \&parseViolations}
);

my $bugId	= 0;
my $fileId	= 0;
my $count	= 0;

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


sub parseViolations {
    my ($tree, $elem) = @_;

    my $bugXpath = $elem->path();

    my $bug = getAndroidLintBugObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;

    $xmlWriterObj->writeBugObject($bug);
}


sub getAndroidLintBugObject  {
    my ($elem, $bugId, $bugXpath) = @_;

    my $bugCode		= $elem->att('id');
    my $severity	= $elem->att('severity');
    my $bugMsg		= $elem->att('message');
    my $category	= $elem->att('category');
    my $priority	= $elem->att('priority');
    my $summary		= $elem->att('summary');
    my $explanation	= $elem->att('explanation');
    my $errorLine	= $elem->att('errorLine2');
    my $errorLinePosition = $elem->att('errorLine1');
    my $url		= $elem->att('url');
    my $urls		= $elem->att('urls');

    my @tokens = split('(\~)', $errorLine) if defined $errorLine;

    my $length = ($#tokens + 1) / 2;

    my $bug = new bugInstance($bugId);
    ###################
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($severity);
    $bug->setBugGroup($category);
    $bug->setBugCode($bugCode);
    $bug->setBugSuggestion($summary);
    $bug->setBugPath($bugXpath . "[$bugId]");
    $bug->setBugBuildId($buildId);
    $bug->setBugReportPath($tempInputFile);
    $bug->setBugPosition($errorLinePosition);
    $bug->setURLText($url . ", " . $urls)  if defined $url;
    my $location_num = 0;

    foreach my $child_elem ($elem->children)  {
	if ($child_elem->gi eq "location")  {
	    my $filePath  = Util::AdjustPath($packageName, $cwd, $child_elem->att('file'));
	    my $lineNum   = $child_elem->att('line');
	    my $beginCol = $child_elem->att('column');
	    my $endCol = $beginCol;;
	    $endCol += $length if $length >= 1;
	    $bug->setBugLocation(
		++$location_num, "", $filePath, $lineNum,
		$lineNum, $beginCol, $endCol, $explanation,
		'true', 'true'
	    );
	}  else  {
	    print "found an unknown tag: " ;
	}
    }
    return $bug;
}
