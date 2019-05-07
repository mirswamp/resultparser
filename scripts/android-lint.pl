#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use XML::Twig;
use Util;
use Parser;


sub parseViolations {
    my ($parser, $tree, $elem, $numIssue) = @_;

    my $bugXpath = "/issues/issue[$numIssue]";
    getAndroidLintBugObject($parser, $elem, $bugXpath);

    $elem->purge() if defined $elem;
}


sub getAndroidLintBugObject  {
    my ($parser, $elem, $bugXpath) = @_;

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

    my $bug = $parser->NewBugInstance();
    ###################
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($severity);
    $bug->setBugGroup($category);
    $bug->setBugCode($bugCode);
    $bug->setBugSuggestion($summary);
    $bug->setBugPath($bugXpath);
    $bug->setBugPosition($errorLinePosition);
    $bug->setURLText($url . ", " . $urls)  if defined $url;
    my $location_num = 0;

    foreach my $child_elem ($elem->children)  {
	my $tag = $child_elem->gi;
	if ($tag eq "location")  {
	    my $filePath  = $child_elem->att('file');
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
	    print "found an unknown tag: $tag in $bugXpath" ;
	}
    }

    $parser->WriteBugObject($bug);
}


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $numIssues = 0;

    my $twig = XML::Twig->new(
	    twig_roots    => {'issues' => 1},
	    twig_handlers => {
		'issue'  => sub {
		    my ($twig, $e) = @_;
		    parseViolations($parser, $twig, $e, $numIssues);
		    ++$numIssues;
		    return 1;
		}
	    }
	);

    $twig->parsefile($fn);
}

my $parser = Parser->new(ParseFileProc => \&ParseFile);
