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

my $locationId;
my $methodId;
my $sourcePathId = 0;
my $count        = 0;

my %cweHash;
my %suggestionHash;
my %categoryHash;
my %sourcePathHash;

my $cwe_xpath      = 'BugCollection/BugPattern';
my $category_xpath = 'BugCollection/BugCategory';
my $source_xpath   = 'BugCollection/Project/SrcDir';
my $xpath1         = 'BugCollection/BugInstance';

my $twig1 = XML::Twig->new(
    twig_roots    => {$cwe_xpath => 1},
    twig_handlers => {$cwe_xpath => \&parseBugPattern}
);

foreach my $inputFile (@inputFiles)  {
    $twig1->parsefile("$inputDir/$inputFile");
}

$twig1->purge();

my $twig2 = XML::Twig->new(
    twig_roots    => {$category_xpath => 1},
    twig_handlers => {$category_xpath => \&parseBugCategory}
);

foreach my $inputFile (@inputFiles)  {
    $twig2->parsefile("$inputDir/$inputFile");
}

$twig2->purge();

my $twig3 = XML::Twig->new(
    twig_roots    => {$source_xpath => 1},
    twig_handlers => {$source_xpath => \&parseSourcePath}
);

foreach my $inputFile (@inputFiles)  {
    $twig3->parsefile("$inputDir/$inputFile");
}

$twig3->purge();

my $twig4 = XML::Twig->new(
    twig_roots    => {$xpath1 => 1},
    twig_handlers => {$xpath1 => \&parseViolations}
);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $locationId = 0;
    $methodId   = 0;
    $buildId   = $buildIds[$count];
    $count++;
    $tempInputFile = $inputFile;
    $twig4->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
$twig4->purge();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub parseViolations {
    my ($tree, $elem) = @_;

    my $bugXpath = $elem->path();

    my $bug = GetFindBugsBugObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;

    $xmlWriterObj->writeBugObject($bug);
    $tree->purge();
}


sub GetFindBugsBugObject  {
    my ($elem, $bugId, $bugXpath) = @_;

    my $bug = new bugInstance($bugId);
    $bug->setBugReportPath($tempInputFile);
    $bug->setBugBuildId($buildId);
    $bug->setBugSeverity($elem->att('priority'));
    $bug->setBugRank($elem->att('rank')) if defined $elem->att('rank');
    $bug->setBugPath($elem->path() . "[" . $bugId . "]") if defined $elem->path();
    $bug->setBugGroup($elem->att('category'));

    my $SourceLineNum = 0;
    my $classNum      = 0;
    my @children      = $elem->children;
    foreach my $itr (@children)  {
	if ($itr->gi eq 'SourceLine')  {$SourceLineNum++;}
    }

    foreach my $itr1 (@children)  {
	    if ($itr1->gi eq 'Class')  {$classNum++;}
    }
    foreach my $element ($elem->children)  {
	my $tag = $element->gi;
	if ($tag eq "LongMessage")  {
	    $bug->setBugMessage($element->text);
	}  elsif ($tag eq 'SourceLine')  {
	    $bug = sourceLine($element, $SourceLineNum, $bug);
	}  elsif ($tag eq 'Method')  {
	    $bug = bugMethod($element, $bug);
	}  elsif ($tag eq 'Class')  {
	    $bug = parseClass($element, $classNum, $bug);
	}
    }
    $bug = bugCweId($elem->att('type'), $bug);
    $bug = bugSuggestion($elem->att('type'), $bug);
    return $bug;
}


sub sourceLine {
    my ($elem, $SourceLineNum, $bug) = @_;

    my $classname       = $elem->att('classname');
    $locationId++;
    my $flag;
    my $sourceFile = $elem->att('sourcepath');
    ($sourceFile, $flag) = &resolveSourcePath($sourceFile);
    my $startLineNo = $elem->att('start');
    my $endLineNo   = $elem->att('end');
    my $startCol    = "0";
    my $endCol      = "0";
    my $message     = $elem->first_child->text if defined $elem->first_child;
    my $primary     = $elem->att('primary');

    if (!defined $primary)  {
	if ($SourceLineNum > 1)  {
	    $primary = "false";
	}  else  {
	    $primary = "true";
	}
    }
    $bug->setBugLocation(
	    $locationId, $classname, $sourceFile, $startLineNo, $endLineNo,
	    $startCol, $endCol, $message, $primary, $flag
    );
    return $bug;
}


sub bugMethod {
    my ($elem, $bug) = @_;

    $methodId++;
    my $classname  = $elem->att('classname');
    my $methodName = $elem->att('name');
    my $primary    = $elem->att('primary');
    $primary = "false" unless defined $primary;
    $bug->setBugMethod($methodId, $classname, $methodName, $primary);
    return $bug;
}


sub parseClass {
    my ($elem, $classNum, $bug) = @_;

    my $classname = $elem->att('classname');
    my $primary   = $elem->att('primary');
    if (defined $primary && ($primary ne 'true') && $classNum > 1)  {
	    return;
    }
    my $children;
    my ($sourcefile, $start, $end, $classMessage, $resolvedFlag);
    if (defined $primary && $primary eq 'true')  {
	foreach $children ($elem->children)  {
	    my $tag = $children->gi;
	    if ($tag eq "SourceLine")  {
		$start      = $children->att('start');
		$end        = $children->att('end');
		$sourcefile = $children->att('sourcepath');
		($sourcefile, $resolvedFlag) = resolveSourcePath($sourcefile);
		$classMessage = $children->first_child->text
			if defined $children->first_child;
	    }
	}
    }
    $bug->setClassAttribs($classname, $sourcefile, $start, $end, $classMessage);
    return $bug;
}

sub resolveSourcePath {
    my ($path) = @_;

    my $pathId;
    my $flag = "false";
    foreach $pathId (sort {$a <=> $b} keys(%sourcePathHash))  {
	if (-e "$sourcePathHash{$pathId}/$path")  {
	    $path = "$sourcePathHash{$pathId}/$path";
	    $flag = "true";
	    last;
	}
    }
    if ($flag eq "true")  {
	$path = Util::AdjustPath($packageName, $cwd, $path);
    }

    #        print $path, "\n";
    return ($path, $flag);
}

sub parseBugPattern {
    my ($tree, $elem) = @_;

    my $type  = $elem->att('type');
    my $cweid = $elem->att('cweid');
    my $suggestion;
    my $element;
    foreach $element ($elem->children)  {
	my $tag = $element->gi;
	if ($tag eq "Details")  {
	    $suggestion = $element->text;
	}
    }
    $cweHash{$type}        = $cweid;
    $suggestionHash{$type} = $suggestion;
    $tree->purge();
}


sub parseBugCategory {
    my ($tree, $elem) = @_;

    my $category = $elem->att('category');
    my $description;
    my $element;
    foreach $element ($elem->children)  {
	my $tag = $element->gi;
	if ($tag eq "Description")  {
	    $description = $element->text;
	}
    }
    $categoryHash{$category} = $description;
    $tree->purge();
}


sub parseSourcePath {
    my ($tree, $elem) = @_;

    my $sourcepath = $elem->text;
    $sourcePathHash{++$sourcePathId} = $sourcepath if defined $sourcepath;
    $tree->purge();
}


sub bugCweId {
    my ($type, $bug) = @_;

    if (defined $type)  {
	my $cweId = $cweHash{$type};
	$bug->setCweId($cweId);
	$bug->setBugCode($type);
    }
    return $bug;
}


sub bugSuggestion {
    my ($type, $bug) = @_;

    if (defined $type)  {
	my $suggestion = $suggestionHash{$type};
	$suggestion =~ s/(^ *)|( *$)//g;
	$suggestion =~ s/\n|\r/ /g;
	$bug->setBugSuggestion($suggestion);
    }
    return $bug;
}
