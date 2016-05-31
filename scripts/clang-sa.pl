#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use Parser;

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
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion,
	@inputFiles) = Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;


my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $tempInputFile;

my $count = 0;
my $bugId = 0;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    my $indexCheckFlag = 1;
    if (!-e "$inputDir/$inputFile/index.html")  {
	$indexCheckFlag = 0;
    }
    opendir(DIR, "$inputDir/$inputFile");
    my @filelist = grep
		    {-f "$inputDir/$inputFile/$_" && $_ ne "index.html" && $_ =~ m/\.html$/}
		    readdir(DIR);

    close(DIR);
    my $file_count = scalar(@filelist);
    die "ERROR!! Clang assessment run did not complete. index.html file is missing. \n"
	    if ($file_count > 0 and $indexCheckFlag eq 0);
    foreach my $file (@filelist)  {
	my $in_file1 = new IO::File("<$inputDir/$inputFile/$file");
	my @lines = grep /<!--.*BUG.*-->/, <$in_file1>;
	close($in_file1);
	my $in_file2 = new IO::File("<$inputDir/$inputFile/$file");
	my @column = grep /class=\"rowname\".*Location.*line/, <$in_file2>;
	close($in_file2);

	my ($BUGFILE, $BUGDESC, $BUGTYPE, $BUGCATEGORY, $BUGLINE, $BUGCOLUMN, $BUGPATHLENGTH);
	foreach my $line (@lines)  {
	    if ($line =~ m/.*BUGFILE/)  {
		$BUGFILE = Util::AdjustPath($packageName, $cwd, bugLine($line));
	    }  elsif ($line =~ m/.*BUGDESC/)  {
		$BUGDESC = bugLine($line);
	    }  elsif ($line =~ m/.*BUGTYPE/)  {
		$BUGTYPE = bugLine($line);
	    }  elsif ($line =~ m/.*BUGCATEGORY/)  {
		$BUGCATEGORY = bugLine($line);
	    }  elsif ($line =~ m/.*BUGLINE/)  {
		$BUGLINE = bugLine($line);
	    }  elsif ($line =~ m/.*BUGPATHLENGTH/)  {
		$BUGPATHLENGTH = bugLine($line);
	    }
	}
	foreach my $line (@column)  {
	    if ($line =~ m/.*line.*column *\d.*/)  {
		$BUGCOLUMN = &bugColumn($line);
	    }
	}
	$bugId++;
	my $bug = new bugInstance($bugId);
	$bug->setBugMessage($BUGDESC);
	$bug->setBugCode($BUGTYPE);
	$bug->setBugGroup($BUGCATEGORY);
	$bug->setBugLocation(
	    1, "", $BUGFILE, $BUGLINE, $BUGLINE, $BUGCOLUMN,
	    "0", "", "true", "true"
	);
	$bug->setBugPathLength($BUGPATHLENGTH);
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath($tempInputFile);
	$xmlWriterObj->writeBugObject($bug);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId()-1);
}


sub bugLine
{
    my ($line) = @_;

    $line =~ s/(<!--)//;
    $line =~ s/-->//;
    $line =~ s/^ *//;
    my ($val1, $val2) = split /\s *\s*/, $line, 2;
    $val2 =~ s/(\n|\r)$//;
    $val2 =~ s/ *$//;
    return ($val2);
}


sub bugColumn {
    my ($line) = @_;

    $line =~ s/^.*> *line *(\d)* *, *column *//;
    $line =~ s/<.*>$//;
    $line =~ s/(\n|\r)$//;
    $line =~ s/ *$//;
    return ($line);
}
