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

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my %severity_hash = (
	'C' => 'Convention',
	'R' => 'Refactor',
	'W' => 'Warning',
	'E' => 'Error',
	'F' => 'Fatal',
	'I' => 'Information'
);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    open(my $fh, "<", "$inputDir/$inputFile")
	    or die "input file not found\n";
    my $msg = " ";
    my $tempBug;
    while (<$fh>)  {
	my ($file, $lineNum, $bugCode, $bugExample, $bugMsg);
	my $line = $_;
	chomp($line);
	if ($line =~ /^Report$/)  {
	    last;
	}

	## checking for comment line or empty line
	if (!($line =~ /^\*{13}/) && !($line =~ /^$/))  {
	    ($file, $lineNum, $bugCode, $bugExample, $bugMsg) = ParseLine($line);
	    if ($file eq "invalid_line")  {
		$msg = $msg . "\n" . $line;
		print "\n*** invalid line";
		if (defined $tempBug)  {
		    $tempBug->setBugMessage($msg);
		}
	    }  else  {
		my $bug = new bugInstance($xmlWriterObj->getBugId());
		if (defined $tempBug)  {
		    $xmlWriterObj->writeBugObject($tempBug);
		}
		my $bugSeverity = SeverityDet(substr($bugCode, 0, 1));
		$bug->setBugLocation(1, "", $file, $lineNum, $lineNum, 0, 0, "", 'true', 'true');
		$msg = $bug->setBugMessage($bugMsg);
		$bug->setBugSeverity($bugSeverity);
		$bug->setBugCode($bugCode);
		$bug->setBugBuildId($buildId);
		$bug->setBugReportPath($tempInputFile);
		$tempBug = $bug;
	    }
	}
    }
    if (defined $tempBug)  {
	$xmlWriterObj->writeBugObject($tempBug);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub ParseLine
{
    my ($line) = @_;

    my @tokens1 = split(":", $line);
    if ($#tokens1 < 2)  {
	return "invalid_line";
    }
    my $file      = Util::AdjustPath($packageName, $cwd, $tokens1[0]);
    my $lineNum  = $tokens1[1];
    my $line_trim = $tokens1[2];

     ## code to join rest of the message (this is done to recover from unwanted split due to : present in message)
    for (my $i = 3 ; $i <= $#tokens1 ; $i++)  {
	$line_trim = $line_trim . ":" . $tokens1[$i];
    }
    $line_trim =~ /\[(.*?)\](.*)/;
    my $bugDescription = $1;
    my $bugMsg = $2;
    $bugMsg =~ s/^\s+//;
    $bugMsg =~ s/\s+$//;
    my ($bugCode, $bugExample);
    ($bugCode, $bugExample) = split(", ", $bugDescription);
    $bugCode =~ s/^\s+//;
    $bugCode =~ s/\s+$//;
    $bugExample   =~ s/^\s+//;
    $bugExample   =~ s/\s+$//;
    return ($file, $lineNum, $bugCode, $bugExample, $bugMsg);
}


sub SeverityDet
{
    my ($char) = @_;

    if (exists $severity_hash{$char})  {
	return ($severity_hash{$char});
    }  else  {
	die "Unknown Severity $char";
    }
}
