#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use XML::Twig;
use Util;
use Parser;




sub parseViolations {
    my ($parser, $tree, $elem, $numError) = @_;

    my $bugXpath = "results/errors/error[$numError]";
    getCppCheckBugObject($parser, $elem, $bugXpath);

    $elem->purge() if defined $elem;
    $tree->purge() if defined $tree;
}


sub getCppCheckBugObject  {
    my ($parser, $violation, $bugXpath) = @_;

    my $bugCode             = $violation->att('id');
    my $bugSeverity         = $violation->att('severity');
    my $bugMsg              = Util::UnescapeCString($violation->att('msg'));
    my $bug_message_verbose = Util::UnescapeCString($violation->att('verbose'));
    my $bug_inconclusive    = $violation->att('inconclusive');
    my $bug_cwe             = $violation->att('cwe');

    my $bug  = $parser->NewBugInstance();
    my $locationId = 0;

    foreach my $error_element ($violation->children)  {
	my $tag    = $error_element->tag;
	my $file   = "";
	my $lineno = "";
	if ($tag eq 'location')  {
	    $file = $error_element->att('file');
	    $lineno = $error_element->att('line');
	    $locationId++;
	    $bug->setBugLocation($locationId, "",
		    $file,
		    $lineno, $lineno, "0", "0", $bugMsg, 'true', 'true');
	}
    }

    $bug->setBugMessage($bug_message_verbose);
    $bug->setBugGroup($bugSeverity);
    $bug->setBugCode($bugCode);
    $bug->setBugPath($bugXpath);
    $bug->setBugInconclusive($bug_inconclusive) if defined $bug_inconclusive;
    $bug->setCweId($bug_cwe) if defined $bug_cwe;
    $parser->WriteBugObject($bug);
    undef $bug;
}


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $numError = 0;

    my $twig = XML::Twig->new(
            twig_roots    => {'errors' => 1},
	    twig_handlers => {
		'error'  => sub {
		    my ($twig, $e) = @_;
		    parseViolations($parser, $twig, $e, $numError);
		    ++$numError;
		    return 1;
		}
	    }
	);

    $twig->parsefile($fn);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
