#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use JSON;
use bugInstance;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile,
	$help, $version);

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
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion,
	@inputFiles) = Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;
my $count = 0;

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my ($bugCode, $bugMsg, $lineNum, $filePath);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $tempInputFile;

if ($toolVersion ne "8ba3536")  {
    my $beginLine;
    my $endLine;
    my $jsonData = "";
    foreach my $inputFile (@inputFiles)  {
	{
	    $tempInputFile = $inputFile;
	    $buildId = $buildIds[$count];
	    $count++;
	    open FILE, "$inputDir/$inputFile"
		    or die "open $inputDir/$inputFile : $!";
	    local $/;
	    $jsonData = <FILE>;
	    close FILE or die "close $inputFile : $!";
	}
	my $jsonObject = JSON->new->utf8->decode($jsonData);

	foreach my $warning (@{$jsonObject->{"results"}})  {
	    my $bug = GetBanditBugObjectFromJson($warning, $xmlWriterObj->getBugId());
	    $xmlWriterObj->writeBugObject($bug);
	}
    }
}  else  {
    foreach my $inputFile (@inputFiles)  {
	$tempInputFile = $inputFile;
	$buildId        = $buildIds[$count];
	$count++;
	my $startBug = 0;
	open(my $fh, "<", "$inputDir/$inputFile")
		or die "unable to open the input file $inputFile";
	while (<$fh>)  {
	    my $line = $_;
	    chomp($line);
	    if ($line =~ /Test results:/)  {
		$startBug = 1;
		next;
	    }
	    next if ($startBug == 0);
	    my $firstLineSeen = 0;
	    if ($line =~ /^\>\>/)  {
		if ($firstLineSeen > 0)  {
		    my $bug = new bugInstance($xmlWriterObj->getBugId());
		    $bug->setBugLocation(1, "", $filePath, $lineNum, $lineNum,
			    "", "", "", 'true', 'true');
		    $bug->setBugCode($bugCode);
		    $bug->setBugMessage($bugMsg);
		    $bug->setBugBuildId($buildId);
		    $bug->setBugReportPath($tempInputFile);
		    $xmlWriterObj->writeBugObject($bug);
		    undef $bugCode;
		    undef $bugMsg;
		    undef $filePath;
		    undef $lineNum;
		}
		$firstLineSeen = 1;
		$line =~ s/^\>\>//;
		$bugCode = $line;
		$bugMsg  = $line;
	    }  else  {
		my @tokens = split("::", $line);
		if ($#tokens == 1)  {
		    $tokens[0] =~ s/^ - //;
		    $filePath = Util::AdjustPath($packageName, $cwd, $tokens[0]);
		    $lineNum = $tokens[1];
		}
	    }
	}
	$fh->close();
    }

}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}

sub GetBanditBugObjectFromJson {
    my ($warning, $bugId) = @_;

    my $bug = new bugInstance($bugId);
    $bug->setBugCode($warning->{"test_name"});
    $bug->setBugMessage($warning->{"issue_text"});
    $bug->setBugSeverity($warning->{"issue_severity"});
    $bug->setBugBuildId($buildId);
    $bug->setBugReportPath($tempInputFile);
    my $beginLine = $warning->{"line_number"};
    my $endLine;

    foreach my $number (@{$warning->{"line_range"}})  {
	$endLine = $number;
    }
    my $filename = Util::AdjustPath($packageName, $cwd, $warning->{"filename"});
    $bug->setBugLocation(
	    1, "", $filename, $beginLine,
	    $endLine, "0", "0", "",
	    'true', 'true'
	);
    return $bug;
}
