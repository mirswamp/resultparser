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

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $file_xpath_stdviol  = 'ResultsSession/CodingStandards/StdViols/StdViol';
my $file_xpath_dupviol  = 'ResultsSession/CodingStandards/StdViols/DupViol';
my $file_xpath_flowviol = 'ResultsSession/CodingStandards/StdViols/FlowViol';

#Initialize the counter values
my $bugId        = 0;
my $fileId      = 0;
my $stdviol_num  = 0;
my $dupviol_num  = 0;
my $flowviol_num = 0;
my @tokens       = split("::", $replaceDir);
my $target       = $tokens[0];
my @srcdir       = @tokens[ 1 .. $#tokens ];
my %replace_paths;
my $locationId = 0;
my $inputFile = "";
my %location_hash;
my $count = 0;
my $tempInputFile;

my $newerVersion = CompareVersion($toolVersion);

if (!$newerVersion)  {
    my $twig = XML::Twig->new(
	    twig_roots    => {'ResultsSession' => 1},
	    twig_handlers => {
		    $file_xpath_stdviol  => \&ParseViolations_StdViol,
		    $file_xpath_dupviol  => \&ParseViolations_DupViol,
		    $file_xpath_flowviol => \&ParseViolations_FlowViol
	    }
    );

    foreach my $path (@srcdir)  {
	my @tokens = split("/", $path);
	$replace_paths{$tokens[$#tokens]} = $path;
    }

    foreach my $ip (@inputFiles)  {
	$buildId = $buildIds[$count];
	$count++;
	$inputFile   = $ip;
	$stdviol_num  = 0;
	$dupviol_num  = 0;
	$flowviol_num = 0;
	$twig->parsefile("$inputDir/$inputFile");
    }
}  else  {
    print "\n***Newer Version***\n";
    my $location_hash_xpath = 'ResultsSession/Scope/Locations/Loc';
    my $twig                = XML::Twig->new(
	    twig_roots    => {'ResultsSession' => 1},
	    twig_handlers => {
		    $location_hash_xpath => \&ParseLocationHash,
		    $file_xpath_stdviol  => \&ParseViolations_StdViol,
		    $file_xpath_dupviol  => \&ParseViolations_DupViol,
		    $file_xpath_flowviol => \&ParseViolations_FlowViol
	    }
    );

    foreach my $ip (@inputFiles)  {
	$inputFile   = $ip;
	$stdviol_num  = 0;
	$dupviol_num  = 0;
	$flowviol_num = 0;
	$twig->parsefile("$inputDir/$inputFile");
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub ParseViolations_StdViol
{
    my ($tree, $elem) = @_;
    my (
	    $beginLine, $endLine, $beginCol, $endCol, $filePath,
	    $bugCode, $bugMsg, $severity, $category, $bugXpath
    );
    $beginLine = $elem->att('ln');
    $endLine   = $beginLine;
    $stdviol_num++;
    if (!$newerVersion)  {
	$filePath = replacePaths($elem->att('locFile'));
    }  else  {
	$filePath = replacePathsFromHash($elem->att('locRef'));
    }
    $filePath  = Util::AdjustPath($packageName, $cwd, $filePath);
    $bugCode   = $elem->att('rule');
    $bugMsg    = $elem->att('msg');
    $severity  = $elem->att('sev');
    $category  = $elem->att('cat');
    $bugXpath = $elem->path();
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
    $bug->setBugReportPath($inputFile);
    $xmlWriterObj->writeBugObject($bug);
    $tree->purge();
}


sub ParseViolations_DupViol
{
    my ($tree, $elem) = @_;
    my ($beginLine, $endLine, $beginCol, $endCol, $filePath,
	$bugCode, $bugMsg, $severity, $category, $bugXpath);
    $locationId = 1;
    $bugCode    = $elem->att('rule');
    $bugMsg     = $elem->att('msg');
    $severity   = $elem->att('sev');
    $category   = $elem->att('cat');
    $bugXpath  = $elem->path();
    foreach my $child_elem ($elem->first_child('ElDescList')->children)  {
	$dupviol_num++;
	my $bug = new bugInstance($xmlWriterObj->getBugId());
	if (!$newerVersion)  {
	    $filePath = replacePaths($elem->att('srcRngFile'));
	}  else  {
	    $filePath = replacePathsFromHash($elem->att('locRef'));
	}
	$filePath  = Util::AdjustPath($packageName, $cwd, $filePath);
	$beginLine = $child_elem->att('srcRngStartln');
	$endLine   = $child_elem->att('srcRngEndLn');
	$beginCol  = $child_elem->att('srcRngStartPos');
	$endCol    = $child_elem->att('srcRngEndPos');
	$bug->setBugMessage($bugMsg);
	$bug->setBugSeverity($severity);
	$bug->setBugGroup($category);
	$bug->setBugCode($bugCode);
	$bug->setBugPath($bugXpath . "[$dupviol_num]");
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath($inputFile);
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

    $locationId = 1;
    $flowviol_num++;
    my $beginLine = $elem->att('ln');
    my $endLine   = $beginLine;
    my $filePath;
    if (!$newerVersion)  {
	$filePath = replacePaths($elem->att('locFile'));
    }  else  {
	$filePath = replacePathsFromHash($elem->att('locRef'));
    }
    $filePath  = Util::AdjustPath($packageName, $cwd, $filePath);
    my $bugCode   = $elem->att('rule');
    my $bugMsg    = $elem->att('msg');
    my $severity  = $elem->att('sev');
    my $bugXpath = $elem->path();

    my $category = GetFlowViolCategory($bugCode);
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
    $bug->setBugReportPath($inputFile);

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
    my $filePath = replacePaths($elem->att('srcRngFile'));
    $filePath = Util::AdjustPath($packageName, $cwd, $filePath);
    my $locMsg  = $elem->att('desc');

    if ($elem->att('ElType') ne ".P")  {
	$bug->setBugLocation(
		$locationId, "", $filePath, $beginLine,
		$endLine, "0", "0", $locMsg,
		'false', 'true'
	);
    }
    foreach my $child_elem ($elem->children)  {
	if ($child_elem->gi eq "ElDescList")  {
	    $bug = ParseElDescList($child_elem, $bug);
	}
    }
    return $bug;
}


sub replacePaths
{
    my ($filePath) = @_;

    foreach my $dir (keys %replace_paths)  {
	my $search_path = $target . "/" . $dir;
	if ($filePath =~ /$search_path/)  {
	    $filePath =~ s/$search_path/$replace_paths{$dir}/;
	    if (-e $filePath)  {
		last;
	    }
	}
    }
    return $filePath;
}


sub GetFlowViolCategory
{
    my ($bugCode) = @_;

    $bugCode =~ s/^\s+//;
    my $category  = "";
    my @bug_split = split(/\./, $bugCode);
    my $x         = @bug_split;
    $x = $x - 2;
    for my $i (0 .. $x)  {
	if ($i == 0)  {
	    $category = $category . $bug_split[$i];
	}  else  {
	    $category = $category . "." . $bug_split[$i];
	}
    }
    return $category;
}


sub CompareVersion
{
    my ($version) = @_;

    my @versionSplit = split(/\./, $version);
    return ($versionSplit[0] >= 10);
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
