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
my $tempInputFile;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $count = 0;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    my $build_stdout_check_flag = 1;
    if (!-e "$inputDir/$inputFile")  {
	print "no inputfile";
	$build_stdout_check_flag = 0;
    }
    die "ERROR!! Revealdroid assessment run did not complete. build_stdout.out file is missing. \n"
	    if ($build_stdout_check_flag eq 0);

    my $file = "build_stdout.out";
    open my $fh, "<", "$inputDir/$inputFile"
	    or die "Could not open file $inputDir/$inputFile";
    my @lines = <$fh>;
    close $fh;
    chomp @lines;
    my $confidence = "";
    my $bugType    = "";
    my $flag       = 0;
    foreach (@lines)  {
	if ($_ =~ /^[Reputation]/)  {
	    my @rep_conf_split = split /:/, $_;
	    $rep_conf_split[1] =~ s/^\s+//;
	    $rep_conf_split[1] =~ s/\s+$//;
	    if ($flag == 1)  {
		$bugType = $rep_conf_split[1];
		last;
	    }  else  {
		$confidence = $rep_conf_split[1];
		$flag       = 1;
	    }
	}
    }
    if (($bugType eq "Benign") and ($confidence == 1))  {
	next;
    }

    #Create Bug Object#
    my $file_data;
    my $bug = new bugInstance($xmlWriterObj->getBugId());
    {
	open FILE, "$inputDir/$inputFile"
		or die "open $inputDir/$inputFile: $!";
	local $/;
	$file_data = <FILE>;
	close FILE or die "close $inputDir/$inputFile: $!";
    }
    $bug->setBugMessage($file_data);
    foreach (@lines)  {
	if ($_ =~ /^[Reputation]/)  {
	    my @reputation_split = split /:/, $_;
	    $reputation_split[1] =~ s/^\s+//;
	    $reputation_split[1] =~ s/\s+$//;
	    $bug->setBugGroup($reputation_split[1]);
	}  elsif ($_ =~ /^[Family]/)  {
	    my @family_split = split /:/, $_;
	    $family_split[1] =~ s/^\s+//;
	    $family_split[1] =~ s/\s+$//;
	    $bug->setBugCode($family_split[1]);
	}
    }
    $xmlWriterObj->writeBugObject($bug);
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}
