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

    $parser->WriteBugObject($bug) if defined $bug;
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
    my $severity = $violation->att('severity');
    $severity = $violation->att('severty') unless defined $severity;  # work around typo bug in csslint
    my $message = $violation->att('message');
    my $bug = $parser->NewBugInstance();

    my $code = $sourceRule;
    # synthesize eslint code if missing
    $code = 'syntax' if $code eq '' && $message =~ /^Parsing error:/;
    $code = 'file-ignored' if $code eq '' && $message =~ /^File ignored because of a matching ignore pattern. Use "--no-ignore" to override\.$/;
 
    # synthesize csslint code if missing
    $code = 'empty-file' if $code eq '' && $message =~ /^Could not read file data. Is the file empty\?$/;
    $code = 'fatal-error' if $code eq '' && $message =~ /^Fatal error, /;

    # remove code from message text, if present
    my $parenCode;
    if (($parenCode) = ($code =~ /^eslint\.rules\.(.*)/))  {
	$message =~ s/\s+\($parenCode\)$//;
    }

    $bug->setBugLocation(1, "", $filePath, $beginLine, $endLine,
	    $beginColumn, 0, "", 'true', 'true');
    $bug->setBugMessage($message);
    $bug->setBugSeverity($severity);
    $bug->setBugGroup($severity);
    $bug->setBugCode($code);
    $bug->setBugPath($bugXpath);
    return $bug;
}


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $numFile = 0;
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
		    ++$numError;
		    ParseViolations($parser, $twig, $e, $filePath, $numFile, $numError);
		    return 1;
		}
	    }
    );

    my $fh = Util::OpenFilteredXmlInputFile($fn);
    $twig->parse($fh);
    close $fh or die "close OpenFilteredXmlInputFile: \$!=$! \$?=$?";
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
