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

    while (my $line = <$fh>)  {
	chomp($line);
	if ($line =~ /.* line (\d+), column (\d+)./)  {
	    my $l  = $1;
	    my $c  = $2;
	    my $l2 = <$fh>;
	    if ($l2 =~ /^  /)  {
		$l2 =~ /.* (\w+)::(\w+) \(Severity: (\d+)\)/;
		my $class = $1;
		my $rule  = $2;
		my $sev   = $3;
		my $msg   = '';
		while (my $l3 = <$fh>)  {
		    if ($l3 =~ /^    /)  {
			$msg = $msg . ' ' . trim($l3);
		    }  elsif ($l3 =~ /^(\w)/)  {
			last;
		    }  elsif ($3 =~ /^$/)  {
			$msg = $msg . "\n\n";
		    }  else  {
			#Nothing to handle!
		    }
		}
	    }
	}
	my $bug = new bugInstance($xmlWriterObj->getBugId());

	#FIXME: Decide on BugCode for perlcritic
	#$bug->setBugCode($msg);
	$bug->setBugMessage($msg);
	$bug->setBugSeverity($sev);
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath(Util::AdjustPath($packageName, $cwd, "$inputDir/$input"));
	$bug->setBugLocation(1, "", $fileName, $l, $l, $c, "", "", 'true', 'true');
	$xmlWriterObj->writeBugObject($bug);
    }
}
close($fh);

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}
