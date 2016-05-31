#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile);

GetOptions(
	"input_dir=s"    => \$inputDir,
	"output_file=s"  => \$outputFile,
	"tool_name=s"    => \$toolName,
	"summary_file=s" => \$summaryFile
) or die("Error");

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser($summaryFile);

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    my $startBug = 0;
    open(my $fh, "<", "$inputDir/$inputFile")
	    or die "Unable to open the input file $inputFile";
    while (<$fh>)  {
	my $line = $_;
	chomp($line);
	if (($line =~ /^$/) or ($line eq '^'))  {
	    next;
	}
	my @fields = split /:/, $line, 4;
	if (scalar @fields eq 4)  {
	    my $bug =
	    new bugInstance($xmlWriterObj->getBugId());
	    $bug->setBugLocation(
		    1, "", trim($fields[0]), trim($fields[1]),
		    trim($fields[1]), "", "", "",
		    'true', 'true'
	    );
	    #FIXME: Decide on BugCode for xmllint
	    $bug->setBugCode(trim($fields[3]));
	    $bug->setBugMessage(trim($fields[3]));
	    $bug->setBugSeverity(trim($fields[2]));
	    $bug->setBugBuildId($buildId);
	    $bug->setBugReportPath(Util::AdjustPath($packageName, $cwd, "$inputDir/$input"));
	    $xmlWriterObj->writeBugObject($bug);
	}
    }
    $fh->close();
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub trim
{
    my ($s) = @_;

    $s =~ s/^\s+|\s+$//g;
    return $s;
}
