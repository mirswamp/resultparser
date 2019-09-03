#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use XML::Twig;
use Util;
use Data::Dumper;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $numBugInstance = 0;

    my %cweHash;
    my %suggestionHash;

    my $commonSourceDirPrefix;
    my @sourceDirList;


    my $cwe_xpath      = 'BugCollection/BugPattern';
    my $source_xpath   = 'BugCollection/Project/SrcDir';
    my $xpath1         = 'BugCollection/BugInstance';

    my $twig = XML::Twig->new(
	twig_roots    => {
	    $cwe_xpath		=> 1,
	    $source_xpath	=> 1,
	},
	twig_handlers => {
	    $cwe_xpath		=> sub {
		my ($twig, $e) = @_;
		parseBugPattern($twig, $e, \%cweHash, \%suggestionHash);
		return 1;
	    },
	    $source_xpath	=> sub {
		my ($twig, $e) = @_;
		parseSourceDir($twig, $e, \@sourceDirList, \$commonSourceDirPrefix);
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
			\%cweHash, \%suggestionHash, $commonSourceDirPrefix);
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
	    $cweHash, $suggestionHash, $commonSourceDirPrefix) = @_;

    my $bugXpath = "/BugCollection/BugInstance[$numBugInstance]";

    my %bugData = (
        sourceLines => []
    );
    my %splits = (
        hasPrimary => 0,
        bugHasSourceLineAnotherInstance => 0,
        safeToSplit => 1,
    );

    GetFindBugsBugObject($parser, $elem, $bugXpath,
	    $cweHash, $suggestionHash, $commonSourceDirPrefix, \%bugData, \%splits);
    $elem->purge() if defined $elem;

    if ($splits{bugHasSourceLineAnotherInstance} && $splits{safeToSplit}) {
        foreach my $l (@{$bugData{sourceLines}}) {
            my $bug = $parser->NewBugInstance();
            SetBugs($bug, \%bugData);

            if ($l->{message} eq "Another occurrence") {
                $l->{message} = "";
            }

            $bug->setBugLocation(0, $l->{classname}, $l->{sourceFile},
                $l->{startLineNo}, $l->{endLineNo}, $l->{startCol}, $l->{endCol},
                $l->{message}, "true", $l->{resolvedFlag}, $l->{noAdjustPath});
            $parser->WriteBugObject($bug);
        }
    } else {
        my $bug = $parser->NewBugInstance();
        SetBugs($bug, \%bugData);

        foreach my $l (@{$bugData{sourceLines}}) {
            $bug->setBugLocation($l->{numSourceLine}, $l->{classname}, $l->{sourceFile},
                $l->{startLineNo}, $l->{endLineNo}, $l->{startCol}, $l->{endCol},
                $l->{message}, $l->{primary}, $l->{resolvedFlag}, $l->{noAdjustPath});
        }
        $parser->WriteBugObject($bug);
    }

    $tree->purge();
}

sub SetBugs {
    my ($bug, $bugData) = @_;

    $bug->setBugSeverity($bugData->{BugSeverity});
    $bug->setBugRank($bugData->{BugRank});
    $bug->setBugPath($bugData->{BugPath});
    $bug->setBugGroup($bugData->{BugGroup});
    $bug->setBugMessage($bugData->{BugMessage});
    $bug->setClassAttribs($bugData->{ClassAttribs}{classname},
        $bugData->{ClassAttribs}{sourcefile}, $bugData->{ClassAttribs}{start},
        $bugData->{ClassAttribs}{end}, $bugData->{ClassAttribs}{classMessage},
        $bugData->{ClassAttribs}{noAdjustPath});
    $bug->setCweId($bugData->{CweId});
    $bug->setBugCode($bugData->{BugCode});
    $bug->setBugSuggestion($bugData->{BugSuggestion});
    foreach my $m (@{$bugData->{Methods}}) {
        $bug->setBugMethod($m->{methodNum}, $m->{classname}, $m->{methodName}, $m->{primary});
    }
}

sub GetFindBugsBugObject
{
    my ($parser, $elem, $bugXpath,
	    $cweHash, $suggestionHash, $commonSourceDirPrefix, $bugData, $splits) = @_;

    $bugData->{BugSeverity} = $elem->att('priority');
    $bugData->{BugRank} = $elem->att('rank') if defined $elem->att('rank');
    $bugData->{BugPath} = $bugXpath;
    $bugData->{BugGroup} = $elem->att('category');

    my $numClass	= 0;
    my $numSourceLine	= 0;
    my $numMethod	= 0;

    foreach my $element ($elem->children)  {
	my $tag = $element->gi;
	if ($tag eq "LongMessage")  {
            $bugData->{BugMessage} = $element->text;
	}  elsif ($tag eq 'SourceLine')  {
	    sourceLine($element, $numSourceLine, $commonSourceDirPrefix, $bugData, $splits);
	    ++$numSourceLine;
	}  elsif ($tag eq 'Method')  {
	    bugMethod($element, $numMethod, $bugData);
	    ++$numMethod;
	}  elsif ($tag eq 'Class')  {
	    parseClass($element, $numClass, $commonSourceDirPrefix, $bugData);
	    ++$numClass
	}
    }
    bugCweId($elem->att('type'), $cweHash, $bugData);
    bugSuggestion($elem->att('type'), $suggestionHash, $bugData);
}


sub sourceLine
{
    my ($elem, $numSourceLine, $commonSourceDirPrefix, $bugData, $splits) = @_;

    my $classname       = $elem->att('classname');
    my $sourceFile = $elem->att('relSourcepath');
    my $noAdjustPath;
    if (defined $sourceFile)  {
	$sourceFile = resolveSourcePath($sourceFile, $commonSourceDirPrefix);
    }  else  {
	$sourceFile = $elem->att('sourcepath');
	$noAdjustPath = 1;
    }
    my $startLineNo = $elem->att('start');
    my $endLineNo   = $elem->att('end');
    my $startCol    = "0";
    my $endCol      = "0";
    my $message     = $elem->first_child->text if defined $elem->first_child;

    my $filename = $elem->att('sourcefile');
    if (defined $startLineNo && defined $endLineNo) {
        if ($startLineNo == $endLineNo) {
            if ($message =~ /^At \Q$filename\E:\[line \Q$startLineNo\E\]$/) {
                $message = "";
            } elsif ($message =~ /^Another occurrence at \Q$filename\E:\[line \Q$startLineNo\E\]$/) {
                $message =~ s/ at \Q$filename\E:\[line \Q$startLineNo\E\]//;
            }
        } else {
            if ($message =~ /^At \Q$filename\E:\[lines \Q$startLineNo\E-\Q$endLineNo\E\]$/) {
                $message = "";
            } elsif ($message =~ /^Another occurrence at \Q$filename\E:\[lines \Q$startLineNo\E-\Q$endLineNo\E\]$/) {
                $message =~ s/ at \Q$filename\E:\[lines \Q$startLineNo\E-\Q$endLineNo\E\]//;
            }
        }
    } else {
        if ($message =~ /^In \Q$filename\E$/) {
            $message = "";
        }
    }

    my $primary     = $elem->att('primary');

    if ($primary) {
        if (!$splits->{hasPrimary}) {
            $splits->{hasPrimary} = 1;
        } else {
            $splits->{safeToSplit} = 0;
        }
    } else {
        if ($elem->att('role') && $elem->att('role') eq 'SOURCE_LINE_ANOTHER_INSTANCE') {
            $splits->{bugHasSourceLineAnotherInstance} = 1;
        } else {
            $splits->{safeToSplit} = 0;
        }
    }

    $primary = "false" unless defined $primary;

    push @{$bugData->{sourceLines}}, {
        numSourceLine => $numSourceLine,
        classname => $classname,
        sourceFile => $sourceFile,
        startLineNo => $startLineNo,
        endLineNo => $endLineNo,
        startCol => $startCol,
        endCol => $endCol,
        message => $message,
        primary => $primary,
        resolvedFlag => (defined $sourceFile ? 'true' : 'false'),
        noAdjustPath => $noAdjustPath,
    };
}


sub bugMethod
{
    my ($elem, $methodNum, $bugData) = @_;

    my $classname  = $elem->att('classname');
    my $methodName = $elem->att('name');
    my $primary    = $elem->att('primary');
    $primary = "false" unless defined $primary;
    push @{$bugData->{Methods}}, {
        methodNum => $methodNum,
        classname => $classname,
        methodName => $methodName,
        primary => $primary
    };
}


sub parseClass
{
    my ($elem, $classNum, $commonSourceDirPrefix, $bugData) = @_;

    my $classname = $elem->att('classname');
    my $primary   = $elem->att('primary');
    if (defined $primary && ($primary ne 'true') && $classNum > 1)  {
	    return;
    }
    my $children;
    my ($sourcefile, $start, $end, $classMessage, $noAdjustPath);
    if (defined $primary && $primary eq 'true')  {
	foreach $children ($elem->children)  {
	    my $tag = $children->gi;
	    if ($tag eq "SourceLine")  {
		$start      = $children->att('start');
		$end        = $children->att('end');
		$sourcefile = $children->att('relSourcepath');
		if (defined $sourcefile)  {
		    $sourcefile = resolveSourcePath($sourcefile, $commonSourceDirPrefix);
		}  else  {
		    $sourcefile = $elem->att('sourcepath');
		    $noAdjustPath = 1;
		}
		$classMessage = $children->first_child->text
			if defined $children->first_child;
	    }
	}
    }

    $bugData->{ClassAttribs} = {
        classname => $classname,
        sourcefile => $sourcefile,
        start => $start,
        end => $end,
        classMessage => $classMessage,
        noAdjustPath => $noAdjustPath
    };
}

sub resolveSourcePath
{
    my ($path, $commonSourceDirPrefix) = @_;

    $path = Util::AdjustPath(undef, $commonSourceDirPrefix, $path)
	    if defined $commonSourceDirPrefix && defined $path;

    return $path;
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



sub CommonDirPrefix
{
    my ($a, $b) = @_;

    return $b unless defined $a;
    return $a unless defined $b;

    my @aComponents = split /(\/)/, $a;
    my @bComponents = split /(\/)/, $b;

    my $prefix = '';

    while (@aComponents && @bComponents)  {
	my $aPart = shift @aComponents;
	my $bPart = shift @bComponents;

	last if $aPart ne $bPart;

	$prefix .= $aPart
    }

    $prefix =~ s/\/+$//;

    return $prefix;
}


sub parseSourceDir
{
    my ($tree, $elem, $sourceDirList, $commonSourceDirPrefix) = @_;

    my $sourceDir = $elem->text;
    if (defined $sourceDir)  {
	push @$sourceDirList, $sourceDir;
	$$commonSourceDirPrefix = CommonDirPrefix($$commonSourceDirPrefix, $sourceDir);
    }
    $tree->purge();
}


sub bugCweId
{
    my ($type, $cweHash, $bugData) = @_;

    if (defined $type)  {
	$bugData->{CweId} = $cweHash->{$type};
	$bugData->{BugCode} = $type;
    }
}


sub bugSuggestion
{
    my ($type, $suggestionHash, $bugData) = @_;

    if (defined $type)  {
	my $suggestion = $suggestionHash->{$type};
	$suggestion =~ s/(^ *)|( *$)//g;
	$suggestion =~ s/\n|\r/ /g;
    	$bugData->{BugSuggestion} = $suggestion;
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
