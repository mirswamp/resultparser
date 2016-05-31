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


sub trim
{
    (my $s = $_[0]) =~ s/^\s+|\s+$//g;
    return $s;
}


#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $fh;
foreach my $inputFile (@inputFiles)  {
    my $startBug = 0;
    $buildId = $buildIds[$count];
    $count++;
    open($fh, "<", "$inputDir/$inputFile")
	    or die "unable to open the input file $inputFile";
    while (<$fh>)  {
	my $line = $_;
	chomp($line);

	#print "$line \n";
	#$line =~ /^line (\d+) column (\d+) - (\w+): (.*)/;
	my @fields     = split /:/, $line;
	my $fileName   = trim($fields[0]);
	my $lineNum    = trim($fields[1]);
	my $colNum     = trim($fields[2]);
	my $err_typ    = trim($fields[3]);
	my $msg        = trim($fields[4]);
	my $bug = new bugInstance($xmlWriterObj->getBugId());

	#FIXME: Decide on BugCode for tidy
	$bug->setBugCode($msg);
	$bug->setBugMessage($msg);
	$bug->setBugSeverity($err_typ);
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath($inputFile);
	$bug->setBugLocation(
		1, "", Util::AdjustPath($packageName, $cwd, $fileName), $lineNum, $lineNum, $colNum,
		"", "", 'true', 'true'
	);
	$xmlWriterObj->writeBugObject($bug);
    }
}
close($fh);

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
