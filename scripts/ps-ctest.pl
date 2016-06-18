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

my $file_xpath_stdviol  = 'ResultsSession/CodingStandards/StdViols/StdViol';
my $file_xpath_dupviol  = 'ResultsSession/CodingStandards/StdViols/DupViol';
my $file_xpath_flowviol = 'ResultsSession/CodingStandards/StdViols/FlowViol';
my $location_hash_xpath = 'ResultsSession/Scope/Locations/Loc';

#Initialize the counter values
my $bugId        = 0;
my $fileId      = 0;
my $filePath    = "";
my $stdviol_num  = 0;
my $dupviol_num  = 0;
my $flowviol_num = 0;
my $locationId   = 0;
my %location_hash;
my $count = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $newerVersion = CompareVersion($toolVersion);
my $twig;

if (!$newerVersion)  {
    $twig = XML::Twig->new(
	    twig_handlers => {
		    $file_xpath_stdviol  => \&ParseViolations_StdViol,
		    $file_xpath_dupviol  => \&ParseViolations_DupViol,
		    $file_xpath_flowviol => \&ParseViolations_FlowViol
	    }
	);
}  else  {
    $twig = XML::Twig->new(
	    twig_roots    => {'ResultsSession' => 1},
	    twig_handlers => {
		    $location_hash_xpath => \&ParseLocationHash,
		    $file_xpath_stdviol  => \&ParseViolations_StdViol,
		    $file_xpath_dupviol  => \&ParseViolations_DupViol,
		    $file_xpath_flowviol => \&ParseViolations_FlowViol
	    }
    );
}

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


sub ParseViolations_StdViol
{
    my ($tree, $elem) = @_;

    $stdviol_num++;
    my $beginLine = $elem->att('ln');
    my $endLine   = $beginLine;
    my $file;
    if (!$newerVersion)  {
	$file = $elem->att('locFile');
	$file =~ s/\/(.*?)\/(.*?\/)/\//;
	$file = $cwd . $file;
    }  else  {
	$file = replacePathsFromHash($elem->att('locRef'));
    }
    my $filePath  = Util::AdjustPath($packageName, $cwd, $file);
    my $bugCode   = $elem->att('rule');
    my $bugMsg    = $elem->att('msg');
    my $severity  = $elem->att('sev');
    my $category  = $elem->att('cat');
    my $bugXpath = $elem->path();
    my $bug = new bugInstance($xmlWriterObj->getBugId());
    $bug->setBugLocation(
	    1, "", $filePath, $beginLine, $endLine, "0",
	    "0", "", 'true', 'true'
    );
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($severity);
    $bug->setBugGroup($category);
    $bug->setBugCode($bugCode);
    $bug->setBugPath($bugXpath . "[$stdviol_num]");
    $bug->setBugBuildId($buildId);
    $bug->setBugReportPath($tempInputFile);
    $tree->purge();
    $xmlWriterObj->writeBugObject($bug);
}


sub ParseViolations_DupViol
{
    my ($tree, $elem) = @_;

    # FIXME: what is locationId
    $locationId = 1;
    my $bugCode    = $elem->att('rule');
    my $bugMsg     = $elem->att('msg');
    my $severity   = $elem->att('sev');
    my $category   = $elem->att('cat');
    my $bugXpath  = $elem->path();
    foreach my $child_elem ($elem->first_child('ElDescList')->children)  {
	$dupviol_num++;
	my $bug = new bugInstance($xmlWriterObj->getBugId());
	my $file;
	if (!$newerVersion)  {
	    $file = $child_elem->att('srcRngFile');
	    $file =~ s/\/(.*?)\/(.*?\/)/\//;
	    $file = $cwd . $file;
	}  else  {
	    $file = replacePathsFromHash($elem->att('locRef'));
	}
	my $filePath  = Util::AdjustPath($packageName, $cwd, $file);
	my $beginLine = $child_elem->att('srcRngStartln');
	my $endLine   = $child_elem->att('srcRngEndLn');
	my $beginCol  = $child_elem->att('srcRngStartPos');
	my $endCol    = $child_elem->att('srcRngEndPos');
	$bug->setBugMessage($bugMsg);
	$bug->setBugSeverity($severity);
	$bug->setBugGroup($category);
	$bug->setBugCode($bugCode);
	$bug->setBugPath($bugXpath . "[$dupviol_num]");
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath($tempInputFile);
	my $locMsg = $child_elem->att('desc');
	$bug->setBugLocation(
		$locationId, "", $filePath, $beginLine,
		$endLine, $beginCol, $endCol, "",
		$locMsg, 'false', 'true'
	);
	$xmlWriterObj->writeBugObject($bug);
    }
    $tree->purge();
}


sub ParseViolations_FlowViol
{
    my ($tree, $elem) = @_;

    # FIXME: what is locationId
    $locationId = 1;
    $flowviol_num++;
    my $beginLine = $elem->att('ln');
    my $endLine   = $beginLine;
    my $file;
    if (!$newerVersion)  {
	$file = $elem->att('locFile');
	$file =~ s/\/(.*?)\/(.*?\/)/\//;
	$file = $cwd . $file;
    }  else  {
	$file = replacePathsFromHash($elem->att('locRef'));
    }
    my $filePath  = Util::AdjustPath($packageName, $cwd, $file);
    my $bugCode   = $elem->att('rule');
    my $bugMsg    = $elem->att('msg');
    my $severity  = $elem->att('sev');
    my $bugXpath = $elem->path();
    my $category;	#FIXME what is the value???
    my $bug = new bugInstance($xmlWriterObj->getBugId());
    $bug->setBugLocation(
	    1, "", $filePath, $beginLine, $endLine, "0",
	    "0", "", 'true', 'true'
    );
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($severity);
    $bug->setBugGroup($category);
    $bug->setBugCode($bugCode);
    $bug->setBugPath($bugXpath . "[$flowviol_num]");
    $bug->setBugBuildId($buildId);
    $bug->setBugReportPath($tempInputFile);

    foreach my $child_elem ($elem->children)  {
	if ($child_elem->gi eq "ElDescList")  {
	    $bug = ParseElDescList($child_elem, $bug);
	}
    }
    $xmlWriterObj->writeBugObject($bug);
}


sub ParseElDescList
{
    my ($elem, $bug) = @_;

    foreach my $child_elem ($elem->children)  {
	if ($child_elem->gi eq "ElDesc")  {
	    $bug = ParseElDesc($child_elem, $bug);
	}
    }
    return $bug;
}


sub ParseElDesc
{
    my ($elem, $bug) = @_;

    $locationId++;
    my $beginLine = $elem->att('ln');
    my $endLine;
    if (defined $elem->att('eln'))  {
	$endLine = $elem->att('eln');
    }  else  {
	$endLine = $beginLine;
    }
    my $file = $elem->att('srcRngFile');
    $file =~ s/\/(.*?)\/(.*?\/)/\//;
    $file     = $cwd . $file;
    my $filePath = Util::AdjustPath($packageName, $cwd, $file);
    my $locMsg  = $elem->att('desc');

    if ($elem->att('ElType') ne ".P")  {
	$bug->setBugLocation($locationId, "", $filePath, $beginLine,
		$endLine, "0", "0", $locMsg, 'false', 'true');
    }
    foreach my $child_elem ($elem->children)  {
	if ($child_elem->gi eq "ElDescList")  {
	    $bug = ParseElDescList($child_elem, $bug);
	}
    }
    return $bug;
}


sub CompareVersion
{
    my ($version) = @_;

    return (index($version, "10.") != -1);
}


sub ParseLocationHash
{
    my ($tree, $elem) = @_;

    my $locRef = $elem->att('locRef');
    my $uri    = $elem->att('uri');
    my $path   = "";
    if ($uri =~ /^file:\/\/[^\/]*(.*)/)  {
	$path = $1;
    }  else  {
	die "Bad file URI $uri.";
    }
    $location_hash{$locRef} = $path;
}


sub replacePathsFromHash
{
    my ($locKey) = @_;

    return $location_hash{$locKey};
}
