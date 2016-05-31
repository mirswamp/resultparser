#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);

GetOptions(
	"input_dir=s"   => \$inputDir,
	"output_file=s"  => \$outputFile,
	"tool_name=s"    => \$toolName,
	"summary_file=s" => \$summaryFile,
	"weakness_count_file=s" => \$weaknessCountFile,
	"help" => \$help,
	"version" => \$version
) or die("Error");

Util::Usage() if defined $help;
Util::Version() if defined $version;

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;
my $tempInputFile;

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;

my %severity_hash = (
	'C' => 'Convention',
	'R' => 'Refactor',
	'W' => 'Warning',
	'E' => 'Error',
	'F' => 'Fatal',
	'I' => 'Information',
);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    open(my $fh, "<", "$inputDir/$inputFile")
	    or die "Input file $inputDir/$inputFile not found \n";
    while (<$fh>)  {
	my ($file, $lineNum, $bugCode, $bugMsg, $bugSeverity);
	my $line = $_;
	chomp($line);
	my @tokens = split(':', $line);
	next if ($#tokens != 2);
	$file = Util::AdjustPath($packageName, $cwd, $tokens[0]);
	$lineNum = $tokens[1];
	$tokens[2] =~ /\[(.*?)\](.*)/;
	$bugCode = $1;
	$bugMsg  = $2;
	my $sever = substr($bugCode, 0, 1);
	$bugSeverity = SeverityDet($sever);
	my $bugObj = new bugInstance($xmlWriterObj->getBugId());
	$bugObj->setBugLocation(1, "", $file, $lineNum, $lineNum, 0, 0, "", 'true', 'true');
	$bugObj->setBugMessage($bugMsg);
	$bugObj->setBugCode($bugCode);
	$bugObj->setBugSeverity($bugSeverity);
	$bugObj->setBugBuildId($buildId);
	$bugObj->setBugReportPath($tempInputFile);
	$xmlWriterObj->writeBugObject($bugObj);
    }
    $fh->close;
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId()-1);
}


sub SeverityDet
{
    my ($char) = @_;

    if (exists $severity_hash{$char})  {
        return($severity_hash{$char});
    }  else  {
        die "Unknown Severity $char";
    }
}
