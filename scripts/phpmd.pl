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

    my $fileName;
    my $numFile = -1;
    my $numViolation = -1;

    my $twig = XML::Twig->new(
	    twig_roots         => {'file'  => 1},
	    start_tag_handlers => {
		'file'  => sub {
		    my ($twig, $e) = @_;
		    ++$numFile;
		    $numViolation = -1;
		    $fileName = $e->att('name');
		    return 1;
		},
	    },
	    twig_handlers      => {
		'violation' => sub {
		    my ($twig, $e) = @_;
		    ++$numViolation;
		    my $xpath = "/pmd/file[$numFile]/violation[$numViolation]";
		    parseViolation($parser, $e, $fileName, $xpath);
		    $twig->purge();
		    return 1;
		},
	    }
    );

    $twig->parsefile($fn);
}


sub parseViolation
{
    my ($parser, $violation, $fileName, $bugXpath) = @_;

    my $beginLine	= $violation->att('beginline');
    my $endLine		= $violation->att('endline');
    my $beginColumn	= (defined $violation->att('column')) ? $violation->att('column') : 0;
    my $endColumn	= $beginColumn;
    my $priority	= $violation->att('priority');
    my $message		= $violation->text;
    $message		=~ s/^\s+|\s+$//g;
    my $bugCode		= $violation->att('rule');
    my $bugGroup	= $violation->att('ruleset');
    my $package		= $violation->att('package');
    my $class		= $violation->att('class');
    my $infoUrl		= $violation->att('externalInfoUrl');
    $message .= " (see $infoUrl)" if defined $infoUrl;
    my $bug   = $parser->NewBugInstance();

    $bug->setBugLocation(1, $class, $fileName, $beginLine, $endLine,
	    $beginColumn, $endColumn, "", 'true', 'true');
    $bug->setBugMessage($message);
    $bug->setBugSeverity($priority);
    $bug->setBugGroup($bugGroup);
    $bug->setBugCode($bugCode);
    $bug->setBugPath($bugXpath);
    $bug->setClassName($class) if defined $class;
    $bug->setURLText($infoUrl);

    $parser->WriteBugObject($bug);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
