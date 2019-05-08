#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
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
    my $bug = $parser->NewBugInstance();
    ###################
    $bug->setBugLocation(
	    1, $class, $fileName, $beginLine,
	    $endLine, $beginColumn, $endColumn, $locMsg,
	    'true', 'true'
    );
    $bug->setBugMessage($message);
    $bug->setClassAttribs($class, $fileName, $beginLine, $endLine, "");
    $bug->setBugSeverity($priority);
    $bug->setBugGroup($ruleset);
    $bug->setBugCode($rule);
    $bug->setBugPath($bugXpath);
    $bug->setBugMethod(1, $class, $method, 'true') if defined $method;
    $bug->setBugPackage($package);
    $bug->setURLText($externalInfoURL);

    $parser->WriteBugObject($bug);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
