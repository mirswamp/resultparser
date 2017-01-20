#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);

GetOptions(
	"input_dir=s"		=> \$inputDir,
	"output_file=s"		=> \$outputFile,
	"tool_name=s"		=> \$toolName,
	"summary_file=s"	=> \$summaryFile,
	"weakness_count_file=s" => \$weaknessCountFile,
	"help"			=> \$help,
	"version"		=> \$version
) or die("Error");

Util::Usage()	if defined $help;
Util::Version() if defined $version;

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;
my $tempInputFile;

my $count = 0;

my $twig = XML::Twig->new(
	twig_handlers => {
		'warning'	     => \&GetFileDetails,
		'warning/categories' => \&GetCWEDetails,
		'warning/listing'    => \&GetListingDetails
	}
    );

#Initialize the counter values
my $filePath = "";
my $eventNum;
my ($line, $bugGroup, $filename, $severity, $method, $bugMsg, $file);
my @bugCode_cweId;    # first element is bug code and other elements are cweids
my $tempBug;
my %buglocation_hash;

my $resultsDir = "$inputDir/$inputFiles[0]";

opendir(DIR, $resultsDir);
my @filelist = grep {-f "$resultsDir/$_" && $_ =~ m/\.xml$/} readdir(DIR);

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@filelist)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    $eventNum	 = 1;
    $bugMsg = "";
    undef($method);
    undef(@bugCode_cweId);
    undef($severity);
    undef($filename);
    undef($bugGroup);
    undef($line);
    $twig->parsefile("$resultsDir/$inputFile");
    my $bug = new bugInstance($xmlWriterObj->getBugId());
    $tempBug = $bug;
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($severity);
    $bug->setBugGroup($bugGroup);
    $bug->setBugCode(shift(@bugCode_cweId));
    $bug->setBugReportPath($tempInputFile);
    $bug->setBugBuildId($buildId,);
    $bug->setBugMethod(1, "", $method, "true");
    $bug->setCWEArray(@bugCode_cweId);
    my @events = sort {$a <=> $b} (keys %buglocation_hash);

    foreach my $elem (sort {$a <= $b} @events)  {
	my $primary = ($elem eq $events[$#events]) ? "true" : "false";
	my @tokens = split(":", $buglocation_hash{$elem});
	$bug->setBugLocation(
	    $elem, "", $tokens[0], $tokens[1],
	    $tokens[1], "0", "0", $tokens[2],
	    $primary, "true"
	);
    }
    $xmlWriterObj->writeBugObject($bug);
    %buglocation_hash = ();
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub GetFileDetails
{
    my ($tree, $elem) = @_;
    $line      = $elem->att('line_number');
    $bugGroup = $elem->att('warningclass');
    $severity  = $elem->att('priority');
    $filename = Util::AdjustPath($packageName, $cwd, $elem->att('filename'));
    $method = $elem->att('procedure');
}


sub GetCWEDetails
{
    my ($tree, $elem) = @_;

    foreach my $cwe ($elem->children('category'))  {
	push(@bugCode_cweId, $cwe->field);
    }
}


sub GetListingDetails
{
    my ($tree, $elem) = @_;

    foreach my $procedure ($elem->children)  {
	ProcedureDetails($procedure, "");
    }

}


sub ProcedureDetails
{
    my ($procedure, $filename) = @_;

    my $procedure_name = $procedure->att('name');
    if (defined $procedure->first_child('file'))  {
	$filename = Util::AdjustPath($packageName, $cwd,
		$procedure->first_child('file')->att('name'));
    }
    foreach my $line ($procedure->children('line'))  {
	LineDetails($line, $procedure_name, $filename);
    }
}


sub LineDetails
{
    my ($line, $procedure_name, $filename) = @_;

    my $lineNum       = $line->att('number');
    my $message;

    foreach my $inner ($line->children)  {
	if ($inner->gi eq 'msg')  {
	    msg_format_star($inner);
	    msg_format($inner);
	    my $message = msg_details($inner);
	    $message =~ s/^\n*//;
	    $eventNum = $inner->att("msg_id");
	    $buglocation_hash{$eventNum} = $filename . ":" . $lineNum . ":" . $message;
	    $bugMsg = "$bugMsg Event $eventNum at $filename:$lineNum: $message\n\n";
	}  else  {
	    InnerDetails($inner, $filename);
	}
    }
}


sub InnerDetails
{
    my ($miscDetails, $filename) = @_;

    if ($miscDetails->gi eq 'procedure')  {
	ProcedureDetails($miscDetails, $filename);
    }  else  {
	foreach my $inner ($miscDetails->children)  {
	    InnerDetails($inner, $filename);
	}
    }
}


sub msg_format_star
{
    my ($msg) = @_;

    my @list;

    @list = $msg->descendants;
    foreach my $elem (@list)  {
	if ($elem->gi eq 'li')  {
	    $elem->prefix("* ");
	}
    }
}


sub msg_format
{
    my ($msg) = @_;

    my @list;
    foreach my $msg_child ($msg->children)  {
	if ($msg_child->gi eq 'ul')  {
	    @list = $msg_child->descendants;
	    foreach my $elem (@list)  {
		if ($elem->gi eq "li")  {
		    $elem->prefix("   ");
		}
	    }
	}
	msg_format($msg_child);
    }

    return;
}


sub msg_details
{
    my ($msg) = @_;

    my $message = $msg->sprint();
    $message =~ s/\<li\>/\n/g;
    $message =~ s/\<link msg="m(.*?)"\>(.*?)\<\/link\>/ [event $1, $2]/g;
    $message =~ s/\<paragraph\>/\n/g;
    $message =~ s/\<link msg="m(.*?)"\>/[event $1] /g;
    $message =~ s/\<.*?\>//g;
    $message =~ s/,\s*]/]/g;
    $message =~ s/&lt;/\</g;
    $message =~ s/&amp;/&/g;
    $message =~ s/&gt;/>/g;
    $message =~ s/&quot;/"/g;
    $message =~ s/&apos;/'/g;
    return $message;
}
