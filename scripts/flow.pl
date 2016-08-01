#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

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

my $xmlWriter = new xmlWriterObject($outputFile);
$xmlWriter->addStartTag($toolName, $toolVersion, $uuid);
my $count = 0;

foreach my $inputFile (@inputFiles)  {
    $buildId = $buildIds[$count];
    $count++;
    my $jsonData;
    {
	open FILE, "$inputDir/$inputFile" or die "open $inputFile: $!";
	local $/;
	$jsonData = <FILE>;
	close FILE or die "close $inputFile: $!";
    }

    my $jsonObject = JSON->new->utf8->decode($jsonData);

    foreach my $error (@{$jsonObject->{"errors"}})  {
	WriteFlowWeakness($error, $xmlWriter->getBugId(), $xmlWriter);
    }
}

$xmlWriter->writeSummary();
$xmlWriter->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriter->getBugId() - 1);
}


sub WriteFlowWeakness  {
    my ($e, $bugId, $xmlWriter) = @_;

    my $bug = new bugInstance($bugId);

    $bug->setBugGroup($e->{kind}) if exists $e->{kind};
    $bug->setBugSeverity($e->{level}) if exists $e->{level};
    my $msgs = $e->{message};

    my $bugCode;
    my $bugMsg;
    my $isPrimary = "true";
    my $locCount = 0;
    foreach my $msg (@$msgs)  {
	++$locCount;
	my $type = $msg->{type};
	if (!defined $bugCode || $type eq 'Comment' && !defined  $msg->{context})  {
	    $bugCode = $msg->{descr};
	}
	$bugMsg .= ' ' if defined $bugMsg;
	my $locMsg = $msg->{descr};
	$bugMsg .= $locMsg;
	
	if (exists $msg->{loc} && $type ne 'libFile')  {
	    my $loc = $msg->{loc};
	    my $startLine = $loc->{start}{line};
	    my $startCol = $loc->{start}{column};
	    my $endLine = $loc->{end}{line};
	    my $endCol = $loc->{end}{column};
	    my $file = Util::AdjustPath($packageName, $cwd, $loc->{source});

	    $bug->setBugLocation($locCount, '', $file, $startLine, $endLine,
				    $startCol, $endCol, $locMsg, $isPrimary, 'true');

	    $isPrimary = 'false';
	}
    }

    # make error message generic instead of including the named export
    $bugCode =~ s/called (['"`]).*?\1/called `*`/g;

    $bug->setBugCode($bugCode);
    $bug->setBugMessage($bugMsg);

    $xmlWriter->writeBugObject($bug);
}
