#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use bugInstance;
use XML::Twig;
use Util;



sub ParseFile
{
    my ($parser, $fn) = @_;

    my $numBugInstance = 0;
    my $numSourcePath = 0;

    my %cweHash;
    my %suggestionHash;
    my %categoryHash;
    my %sourcePathHash;

    my $cwe_xpath      = 'BugCollection/BugPattern';
    my $category_xpath = 'BugCollection/BugCategory';
    my $source_xpath   = 'BugCollection/Project/SrcDir';
    my $xpath1         = 'BugCollection/BugInstance';

    my $twig = XML::Twig->new(
	twig_roots    => {
	    $cwe_xpath		=> 1,
	    $category_xpath	=> 1,
	    $source_xpath	=> 1,
	},
	twig_handlers => {
	    $cwe_xpath		=> sub {
		my ($twig, $e) = @_;
		parseBugPattern($twig, $e, \%cweHash, \%suggestionHash);
		return 1;
	    },
	    $category_xpath	=> sub {
		my ($twig, $e) = @_;
		parseBugCategory($twig, $e, \%categoryHash);
		return 1;
	    },
	    $source_xpath	=> sub {
		my ($twig, $e) = @_;
		parseSourcePath($twig, $e, \%sourcePathHash, $numSourcePath);
		++$numSourcePath;
		return 1;
	    },
	}
    );

    $twig->parsefile($fn);
    $twig->purge();

    $twig = XML::Twig->new(
	twig_roots    => {$xpath1 => 1},
	twig_handlers => {
	    $xpath1 => sub {
		my ($twig, $e) = @_;
		parseViolations($parser, $twig, $e, $numBugInstance,
			\%cweHash, \%suggestionHash, \%categoryHash, \%sourcePathHash);
		++$numBugInstance;
		return 1;
	    },
	}
    );

    $twig->parsefile($fn);
}


sub parseViolations
{
    my ($parser, $tree, $elem, $numBugInstance,
	    $cweHash, $suggestionHash, $categoryHash, $sourcePathHash) = @_;

    my $bugXpath = "/BugCollection/BugInstance[$numBugInstance]";

    my $bug = GetFindBugsBugObject($parser, $elem, $bugXpath,
	    $cweHash, $suggestionHash, $categoryHash, $sourcePathHash);
    $elem->purge() if defined $elem;

    $parser->WriteBugObject($bug);
    $tree->purge();
}


sub GetFindBugsBugObject
{
    my ($parser, $elem, $bugXpath,
	    $cweHash, $suggestionHash, $categoryHash, $sourcePathHash) = @_;

    my $bug = $parser->NewBugInstance();
    $bug->setBugSeverity($elem->att('priority'));
    $bug->setBugRank($elem->att('rank')) if defined $elem->att('rank');
    $bug->setBugPath($bugXpath);
    $bug->setBugGroup($elem->att('category'));

    my $numClass	= 0;
    my $numSourceLine	= 0;
    my $numMethod	= 0;

    foreach my $element ($elem->children)  {
	my $tag = $element->gi;
	if ($tag eq "LongMessage")  {
	    $bug->setBugMessage($element->text);
	}  elsif ($tag eq 'SourceLine')  {
	    $bug = sourceLine($element, $bug, $numSourceLine, $sourcePathHash);
	    ++$numSourceLine;
	}  elsif ($tag eq 'Method')  {
	    $bug = bugMethod($element, $bug, $numMethod);
	    ++$numMethod;
	}  elsif ($tag eq 'Class')  {
	    $bug = parseClass($element, $numClass, $bug, $sourcePathHash);
	    ++$numClass
	}
    }
    $bug = bugCweId($elem->att('type'), $bug, $cweHash);
    $bug = bugSuggestion($elem->att('type'), $bug, $suggestionHash);
    return $bug;
}


sub sourceLine
{
    my ($elem, $bug, $numSourceLine, $sourcePathHash) = @_;

    my $classname       = $elem->att('classname');
    my $flag;
    my $sourceFile = $elem->att('sourcepath');
    ($sourceFile, $flag) = resolveSourcePath($sourceFile, $sourcePathHash);
    my $startLineNo = $elem->att('start');
    my $endLineNo   = $elem->att('end');
    my $startCol    = "0";
    my $endCol      = "0";
    my $message     = $elem->first_child->text if defined $elem->first_child;
    my $primary     = $elem->att('primary');

    $primary = "false" unless defined $primary;
    $bug->setBugLocation(
	    $numSourceLine, $classname, $sourceFile, $startLineNo, $endLineNo,
	    $startCol, $endCol, $message, $primary, $flag
    );
    return $bug;
}


sub bugMethod
{
    my ($elem, $bug, $methodNum) = @_;

    my $classname  = $elem->att('classname');
    my $methodName = $elem->att('name');
    my $primary    = $elem->att('primary');
    $primary = "false" unless defined $primary;
    $bug->setBugMethod($methodNum, $classname, $methodName, $primary);
    return $bug;
}


sub parseClass
{
    my ($elem, $classNum, $bug, $sourcePathHash) = @_;

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
		($sourcefile, $resolvedFlag) = resolveSourcePath($sourcefile, $sourcePathHash);
		$classMessage = $children->first_child->text
			if defined $children->first_child;
	    }
	}
    }
    $bug->setClassAttribs($classname, $sourcefile, $start, $end, $classMessage);
    return $bug;
}

sub resolveSourcePath
{
    my ($path, $sourcePathHash) = @_;

    my $pathId;
    my $flag = "false";
    foreach $pathId (sort {$a <=> $b} keys(%$sourcePathHash))  {
	if (-e "$sourcePathHash->{$pathId}/$path")  {
	    $path = "$sourcePathHash->{$pathId}/$path";
	    $flag = "true";
	    last;
	}
    }

    return ($path, $flag);
}


sub parseBugPattern
{
    my ($tree, $elem, $cweHash, $suggestionHash) = @_;

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
    $cweHash->{$type}        = $cweid;
    $suggestionHash->{$type} = $suggestion;
    $tree->purge();
}


sub parseBugCategory
{
    my ($tree, $elem, $categoryHash) = @_;

    my $category = $elem->att('category');
    my $description;
    my $element;
    foreach $element ($elem->children)  {
	my $tag = $element->gi;
	if ($tag eq "Description")  {
	    $description = $element->text;
	}
    }
    $categoryHash->{$category} = $description;
    $tree->purge();
}


sub parseSourcePath
{
    my ($tree, $elem, $sourcePathHash, $numSourcePath) = @_;

    my $sourcepath = $elem->text;
    $sourcePathHash->{$numSourcePath} = $sourcepath if defined $sourcepath;
    $tree->purge();
}


sub bugCweId
{
    my ($type, $bug, $cweHash) = @_;

    if (defined $type)  {
	my $cweId = $cweHash->{$type};
	$bug->setCweId($cweId);
	$bug->setBugCode($type);
    }
    return $bug;
}


sub bugSuggestion
{
    my ($type, $bug, $suggestionHash) = @_;

    if (defined $type)  {
	my $suggestion = $suggestionHash->{$type};
	$suggestion =~ s/(^ *)|( *$)//g;
	$suggestion =~ s/\n|\r/ /g;
	$bug->setBugSuggestion($suggestion);
    }
    return $bug;
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
