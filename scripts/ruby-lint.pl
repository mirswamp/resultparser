#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);

GetOptions(
	"input_dir=s"           => \$inputDir,
	"output_file=s"         => \$outputFile,
	"tool_name=s"           => \$toolName,
	"summary_file=s"        => \$summaryFile,
	"weakness_count_file=s" => \$$weaknessCountFile,
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

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my %severity_hash = ('W' => 'warning', 'I' => 'info', 'E' => 'error');

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $tempInputFile;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    open(my $fh, "<", "$inputDir/$inputFile")
	    or die "Could not open the input file : $!";
    while (<$fh>)  {
	my $curr_line   = $_;
	my @tokens      = split(/:/, $curr_line, 5);
	my $file        = Util::AdjustPath($packageName, $cwd, $tokens[0]);
	my $severity    = $severity_hash{$tokens[1]};
	my $line        = $tokens[2];
	my $column      = $tokens[3];
	my $bugMsg = $tokens[4];
	chomp($bugMsg);
	my $bugCode   = BugCode($bugMsg);
	my $bug = new bugInstance($xmlWriterObj->getBugId());
	$bug->setBugLocation(
		1, "", $file, $line, $line, $column,
		$column, "", 'true', 'true'
	);
	$bug->setBugMessage($bugMsg);
	$bug->setBugSeverity($severity);
	$bug->setBugCode($bugCode);
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath(Util::AdjustPath($packageName, $cwd, "$inputDir/$input"));
	$xmlWriterObj->writeBugObject($bug);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}

sub BugCode
{
    my ($bugMsg) = @_;

    if ($bugMsg =~ /Comparing/)  {
	return 'UselessEqualityChecks';
    }  elsif ($bugMsg =~ /unused/)  {
	return 'UnusedVariables';
    }  elsif ($bugMsg =~ /undefined method/)  {
	return 'UndefinedMethods';
    }  elsif ($bugMsg =~ /undefined/)  {
	return 'UndefinedVariables';
    }  elsif ($bugMsg =~ /shadowing outer/)  {
	return 'ShadowingVariables';
    }  elsif ($bugMsg =~ /can only be used inside/)  {
	return 'LoopKeywords';
    }  elsif ($bugMsg =~ /wrong number of arguments/)  {
	return 'ArgumentAmount';
    }

    return $bugMsg;
}
