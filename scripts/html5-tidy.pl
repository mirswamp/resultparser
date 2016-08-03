#!/usr/bin/perl -w

use strict;
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


#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my $xmlWriter = new xmlWriterObject($outputFile);
$xmlWriter->addStartTag($toolName, $toolVersion, $uuid);

my $fh;
foreach my $inputFile (@inputFiles)  {
    my $startBug = 0;
    $buildId = $buildIds[$count];
    $count++;
    open($fh, "<", "$inputDir/$inputFile")
	    or die "unable to open the input file $inputFile";
    my $lineNum = 0;
    while (<$fh>)  {
	my $line = $_;
	chomp($line);

	++$lineNum;

	if ($line =~ /^\s*(.+?)\s*:\s*(\d+)\s*:\s*(\d+)\s*:\s*(.+?)\s*:\s*(.*?)\s*$/)  {
	    my ($file, $line, $col, $bugGroup, $bugMsg) = ($1, $2, $3, $4, $5);
	    my $path = Util::AdjustPath($packageName, $cwd, $file);
	    my $bugLocId = 1;
	    my $bugCode = $bugMsg;
	    $bugCode =~ s/\s*(<.*?>|(['"`]).*?\2)\s*/ /g;
	    $bugCode =~ s/\+ \+|U\+[0-9a-f]+//ig;
	    $bugCode =~ s/^\s+//;
	    $bugCode =~ s/\s+$//;

	    my $bug = new bugInstance($count);

	    $bug->setBugGroup($bugGroup);
	    $bug->setBugCode($bugCode);
	    $bug->setBugMessage($bugMsg);
	    $bug->setBugReportPath("$inputFile:$lineNum");
	    $bug->setBugLocation($bugLocId, '', $path, $line, $line, $col, $col, $bugMsg, 'true', 'true');

	    $xmlWriter->writeBugObject($bug);
	}  else  {
	    print STDERR "$0: bad line at $inputFile; $lineNum\n";
	}
    }
}
close($fh);

$xmlWriter->writeSummary();
$xmlWriter->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriter->getBugId() - 1);
}
