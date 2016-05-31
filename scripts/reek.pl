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

my $fileId      = 0;
my $current_file = "";
my $count        = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

if ($inputFiles[0] =~ /\.json$/)  {
    foreach my $inputFile (@inputFiles)  {
	$current_file = $inputFile;
	$fileId++;
	$buildId = $buildIds[$count];
	$count++;
	my $bug = ParseJsonOutput("$inputDir/$inputFile");
	$xmlWriterObj->writeBugObject($bug);
    }
}  elsif ($inputFiles[0] =~ /\.xml$/)  {
    my $twig = XML::Twig->new(
	    twig_handlers => {'checkstyle/file' => \&ParseViolations});
    foreach my $inputFile (@inputFiles)  {
	$current_file = $inputFile;
	$buildId = $buildIds[$count];
	$count++;
	$fileId++;
	$twig->parsefile("$inputDir/$inputFile");
    }
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub parseJsonOutput
{
    my ($inputFile) = @_;

    my $beginLine;
    my $endLine;
    my $jsonData = "";
    my $filename;
    my $json_obj = "";
    {
	open FILE, $inputFile or die "open $inputFile: $!";
	local $/;
	$jsonData = <FILE>;
	close FILE or die "close $inputFile: $!";
    }
    $json_obj = JSON->new->utf8->decode($jsonData);
    foreach my $warning (@{$json_obj})  {
	my $bugObj = new bugInstance($xmlWriterObj->getBugId());

	$bugObj->setBugCode($warning->{"smell_type"});
	$bugObj->setBugMessage($warning->{"message"});
	$bugObj->setBugBuildId($buildId);
	$bugObj->setBugReportPath($current_file);
	$bugObj->setBugPath("[" 
		  . $fileId . "]"
		  . "/error["
		  . $xmlWriterObj->getBugId()
		  . "]");
	$bugObj->setBugGroup($warning->{"smell_category"});
	my $lines      = $warning->{"lines"};
	my $startLine = @{$lines}[0];
	my $endLine;

	foreach (@{$lines})  {
	    $endLine = $_;
	}
	$filename = Util::AdjustPath($packageName, $cwd, $warning->{"source"});
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
	$xmlWriterObj->writeBugObject($bugObj);
    }
}


sub ParseViolations
{
    my ($tree, $elem) = @_;

    #Extract File Path#
    my $filePath = Util::AdjustPath($packageName, $cwd, $elem->att('name'));
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

	my $bug = new bugInstance($xmlWriterObj->getBugId());
	$bug->setBugLocation(
		1, "", $filePath, $beginLine,
		$endLine, $beginColumn, $endColumn, "",
		'true', 'true'
	);
	$bug->setBugMessage($message);
	$bug->setBugSeverity($severity);
	$bug->setBugCode($rule);
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath($current_file);
	$bug->setBugPath($bugXpath . "[" 
		. $fileId . "]"
		. "/error["
		. $xmlWriterObj->getBugId()
		. "]");
	$xmlWriterObj->writeBugObject($bug);
    }
}
