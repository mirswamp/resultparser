#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

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

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $count = 0;

foreach my $inputFile (@inputFiles)  {
    $buildId = $buildIds[$count];
    $count++;
    my $jsonData;
    {
	open FILE, "$inputDir/$inputFile" or die "open $inputFile: $!";
	local $/;
	$jsonData = <FILE>;
	close FILE or die "close $inputFile: $!";
    }

    my $jsonObject = JSON->new->utf8->decode($jsonData);

    foreach my $error (@{$jsonObject->{"errors"}})  {
	GetFlowObject($error, $xmlWriterObj->getBugId());
    }
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub GetFlowObject  {
    my ($e, $bugId) = @_;

    my $error_message = "";
    my @messages      = @{$e->{"message"}};
    my $bugCode      = "";
    my $location_id   = 0;
    my $bug    = new bugInstance($bugId);
    my $first_flag    = 1;
    foreach my $msg (@{$e->{"message"}})  {
	if ($error_message eq "")  {
	    $error_message .= $msg->{"descr"};
	}  else  {
	    $error_message .= " " . $msg->{"descr"};
	}
	$location_id++;
	my $file;
	my $loc_arr = $messages[0]->{"loc"};
	$file = $loc_arr->{"source"};
	my $loc_arr = $msg->{"loc"};
	if (defined $loc_arr)  {
	    my $primary = "false";
	    if ($first_flag)  {
		    $primary    = "true";
		    $first_flag = 0;
	    }
	    $bug->setBugLocation($location_id, "",
		    Util::AdjustPath($packageName, $cwd, $file),
		    $msg->{"start"}, $msg->{"end"}, 0, 0, $msg->{"descr"}, $primary,
		    "true");
	}
	if ($msg->{"type"} eq "Comment")  {
	    $bugCode = $msg->{"descr"};
	}
    }
    if ($bugCode eq "")  {
	$bugCode = $messages[0]->{"descr"};
    }

    my $startLine = $messages[0]->{"start"};
    my $endLine   = $messages[0]->{"end"};

    $bug->setBugMessage($error_message);
    $bug->setBugCode($bugCode);
    $bug->setBugSeverity($e->{"level"});
    $bug->setBugGroup($e->{"level"});
    $xmlWriterObj->writeBugObject($bug);
}
