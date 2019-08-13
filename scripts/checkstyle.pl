#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use XML::Twig;
use Util;


sub ParseViolations
{
    my ($parser, $tree, $elem, $filePath, $numFile, $numError) = @_;

    my $bugXpath = "/checkstyle/file[$numFile]/error[$numError]";

    my $bug = GetCheckstyleBugObject($parser, $elem, $filePath, $bugXpath);

    $tree->purge() if defined $tree;

    $parser->WriteBugObject($bug);
}


sub GetCheckstyleBugObject  {
    my ($parser, $violation, $filePath, $bugXpath) = @_;

    my $beginLine = $violation->att('line');
    $beginLine = undef if defined $beginLine && $beginLine eq 'undefined';
    my $endLine = $beginLine;
    my $beginColumn = $violation->att('column');
    $beginColumn = undef if defined $beginColumn && $beginColumn eq 'undefined';
    my $endColumn = $beginColumn;
    my $sourceRule = $violation->att('source');
    my $priority = $violation->att('severity');
    my $message = $violation->att('message');
    my $bug = $parser->NewBugInstance();

    $bug->setBugLocation(1, "", $filePath, $beginLine, $endLine,
	    $beginColumn, 0, "", 'true', 'true');
    $bug->setBugMessage($message);
    $bug->setBugSeverity($priority);
    $bug->setBugGroup($priority);
    $bug->setBugCode($sourceRule);
    $bug->setBugPath($bugXpath);
    return $bug;
}


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $numFile = -1;
    my $numError = 0;
    my $filePath;

    my $twig = XML::Twig->new(
	    twig_roots         => {'file'  => 1},
	    start_tag_handlers => {
		'file'  => sub {
		    my ($twig, $e) = @_;
		    ++$numFile;
		    $numError = 0;
		    $filePath = $e->att('name');
		    return 1;
		}
	    },
	    twig_handlers      => {
		'error' => sub {
		    my ($twig, $e) = @_;
		    ParseViolations($parser, $twig, $e, $filePath, $numFile, $numError);
		    ++$numError;
		    return 1;
		}
	    }
    );

    my $fh = Util::OpenFilteredXmlInputFile($fn);
    $twig->parse($fh);
    close $fh or die "close OpenFilteredXmlInputFile: \$!=$! \$?=$?";
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
