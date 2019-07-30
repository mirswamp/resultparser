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

    if ($fn =~ /\.json$/)  {
	ParseJsonOutput($parser, $fn);
    }  elsif ($fn =~ /\.xml$/)  {
	ParseXmlOutput($parser, $fn);
    }  else  {
	die "Unknown file type: $fn";
    }
}


#
# FIX ME, this is not correct, need $parser, ...
sub ParseXmlOutput
{
    my ($parser, $fn) = @_;
    my $twig = XML::Twig->new(
	    twig_handlers => {'checkstyle/file' => \&ParseViolations});
    $twig->parsefile($fn);
}


sub ParseJsonOutput
{
    my ($parser, $fn) = @_;

    my $beginLine;
    my $endLine;
    my $filename;
    my $jsonObject = Util::ReadJsonFile($fn);
    my $weaknessPos = -1;
    foreach my $warning (@{$jsonObject})  {
	++$weaknessPos;
	my $bugObj = $parser->NewBugInstance();

	$bugObj->setBugGroup('warning');
	$bugObj->setBugCode($warning->{"smell_type"});
	$bugObj->setBugMessage($warning->{"message"});
	# this is jsonpath, not xpath
	$bugObj->setBugPath("\$[$weaknessPos]");
	$bugObj->setBugGroup($warning->{"smell_category"});
	my $lines      = $warning->{"lines"};
	my $startLine = @{$lines}[0];
	my $endLine;

	# FIX ME dumb way to get the last array element
	# FIX ME these lines are not a range, but individual locations
	foreach (@{$lines})  {
	    $endLine = $_;
	}
	$filename = $warning->{"source"};
	$bugObj->setBugLocation(
		1, "", $filename, $startLine,
		$endLine, "0", "0", "",
		'true', 'true'
	);
	my $context     = $warning->{"context"};
	my $className  = "";
	my $method_name = "";
	if ($context =~ m/#/)  {
	    my @context_split = split /#/, $context;
	    if ($context_split[0] ne "")  {
		$className = $context_split[0];
		$bugObj->setClassName($className);
		if ($context_split[1] ne "")  {
		    $method_name = $context_split[1];
		    $bugObj->setBugMethod('1', $className, $method_name, 'true');
		}
	    }
	}  else  {
	    # FIX ME use a hash
	    my @smell_type_list = (
		    'ModuleInitialize', 'UncommunicativeModuleName',
		    'IrresponsibleModule', 'TooManyInstanceVariables',
		    'TooManyMethods', 'PrimaDonnaMethod',
		    'DataClump', 'ClassVariable',
		    'RepeatedConditional'
	    );
	    foreach (@smell_type_list)  {
		if ($_ eq $warning->{'smell_type'})  {
		    $bugObj->setClassName($context);
		    last;
		}
	    }
	    if ($warning->{'smell_type'} eq "UncommunicativeVariableName")  {
		if ($context =~ /^[@]/)  {
		    $bugObj->setClassName($context);
		}  elsif ($context =~ /^[A-Z]/)  {
		    $bugObj->setClassName($context);
		}  else  {
		    $bugObj->setBugMethod('1', "", $method_name, 'true');
		}
	    }
	}
	$parser->WriteBugObject($bugObj);
    }
}


sub ParseViolations
{
    # FIXME include $parser in parameters
    my $parser;
    my ($tree, $elem) = @_;

    #Extract File Path#
    my $filePath = $elem->att('name');
    my $bugXpath = $elem->path();
    my $violation;
    foreach $violation ($elem->children)  {
	my $beginColumn = $violation->att('column');
	my $endColumn   = $beginColumn;
	my $beginLine   = $violation->att('line');
	my $endLine     = $beginLine;
	if ($beginLine > $endLine)  {
	    my $t = $beginLine;
	    $beginLine = $endLine;
	    $endLine   = $t;
	}
	my $message = $violation->att('message');
	$message =~ s/\n//g;
	my $severity = $violation->att('severity');
	my $rule     = $violation->att('source');

	my $bug = $parser->NewBugInstance();
	$bug->setBugLocation(
		1, "", $filePath, $beginLine,
		$endLine, $beginColumn, $endColumn, "",
		'true', 'true'
	);
	$bug->setBugMessage($message);
	$bug->setBugSeverity($severity);
	$bug->setBugCode($rule);
	$bug->setBugPath($bugXpath);
	$parser->WriteBugObject($bug);
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
