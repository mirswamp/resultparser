#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use Parser;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);

my $parser = new Parser();
$parser->InitializeParser();

my $count = 0;
$inputDir = $parser->GetInputDir();
my $bugId = 0;

foreach my $inputFile ($parser->GetInputFileArr())  {
    my $buildId = $parser->GetBuildID($count);
    $count++;
    my $indexCheckFFlag = 1;
    if (!-e "$inputDir/$inputFile/index.html")  {
	$indexCheckFFlag = 0;
    }
    opendir(DIR, "$inputDir/$inputFile");
    my @filelist = grep
			{-f "$inputDir/$inputFile/$_" && $_ ne "index.html" && $_ =~ m/\.html$/}
			readdir(DIR);

    close(DIR);
    my $file_count = scalar(@filelist);
    die "ERROR!! Clang assessment run did not complete. index.html file is missing. \n"
	    if ($file_count > 0 and $indexCheckFFlag eq 0);
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
		$BUGFILE =
			Util::AdjustPath($parser->GetPackageName(), $parser->GetCWD(), bugLine($line));
	    }  elsif ($line =~ m/.*BUGDESC/)  {
		$BUGDESC = bugLine($line);
	    }  elsif ($line =~ m/.*BUGTYPE/)  {
		$BUGTYPE = bugLine($line);
	    }  elsif ($line =~ m/.*BUGCATEGORY/)  {
		$BUGCATEGORY = bugLine($line);
	    }  elsif ($line =~ m/.*BUGLINE/)
		{$BUGLINE = bugLine($line);
	    }  elsif ($line =~ m/.*BUGPATHLENGTH/)  {
		$BUGPATHLENGTH = bugLine($line);
	    }
	}
	foreach my $line (@column)  {
	    if ($line =~ m/.*line.*column *\d.*/)  {
		$BUGCOLUMN = bugColumn($line);
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
	$bug->setBugReportPath(Util::AdjustPath($parser->GetPackageName(), $parser->GetCWD(),
						"$inputDir/$inputFile/$file"));
	$parser->writeBugObject($bug);
    }
}
$parser->EndXML();


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
