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
my $tempInputFile;

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

my $prevMsg;
my $prev_fn;
my $prev_line;
my $traceStartLine;
my $suggested_message;
my $currentLineNum;
my $not_msg;
my $first_report
  ; #this variable is defined so that the first bug report of a file doesnot try to change the bug instance of its previous bug report.
my $input_text;
my $tempBug;

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    $not_msg	       = 0;
    $prev_line         = "";
    $first_report      = 1;
    $suggested_message = "";
    $currentLineNum   = 0;
    $prevMsg          = "";
    $prev_fn           = "";
    $traceStartLine  = 1;
    $input_text        = new IO::File("<$inputDir/$inputFile");

    my $tempBug;
    $input_text = (defined $input_text) ? $input_text : "";
    my $temp;

  LINE:
    while (my $line = <$input_text>)  {
	chomp($line);
	$currentLineNum = $.;
	my @tokens = split(':', $line);
	#FIXME | should be ||
	if (($#tokens != 3 && $not_msg == 1) | (($#tokens == 3) && !($tokens[3] =~ /^\s*\[.*\]/)))  {
	    $not_msg = 1;
	    next;
	}  else  {
	    $not_msg = 0;
	}

	if ($line eq $prev_line)  {
	    next LINE;
	}  else  {
	    $prev_line = $line;
	}
	ParseLine($currentLineNum, $line, $inputFile);
	$temp = $line;
    }
    RegisterBugPath($currentLineNum, $inputFile);
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub ParseLine {
    my ($bugReportLine, $line, $inputFile) = @_;

    my @tokens        = SplitString($line);
    my $num_of_tokens = @tokens;
    my ($file, $lineNum, $message, $severity, $code, $resolution_msg);
    my $flag = 1;
    if ($num_of_tokens eq 4 && !($line =~ m/^\s*Did you mean.*$/i))  {
	$file     = Util::AdjustPath($packageName, $cwd, $tokens[0]);
	$lineNum  = $tokens[1];
	$severity = Util::Trim($tokens[2]);
	$message  = $tokens[3];
	$code     = $message;
	$code =~ /^\s*\[(.*)\].*$/;
	$code = $1;
    }  elsif ($line =~ m/^\s*Did you mean.*$/i)  {
	$resolution_msg = Util::Trim($line);
	SetResolutionMsg($resolution_msg);
	$flag = 0;
    }  elsif ($line =~ m/^\s*required:.*/i)  {
	$suggested_message = Util::Trim($line);
	$flag              = 0;
    }  elsif ($line =~ m/^\s*found:.*/i)  {
	$suggested_message = $suggested_message . ", " . Util::Trim($line);
	SetResolutionMsg($suggested_message);
	$flag              = 0;
	$suggested_message = "";
    }  elsif ($line =~ m/^\s*see http:.*/i)  {
	my $url_text = Util::Trim($line);
	SetURLText($url_text);
	$flag = 0;
    }  elsif ($line =~ m/^\s*\^.*/i)  {
	my $column = length $line;
	$column = $column - 1;
	$flag   = 0;
	SetColumnNumber($column);
    }  else  {
	$flag = 0;
    }

    if ($flag ne 0)  {
	$message = Util::Trim($message);

	$tempBug = CreateBugObject($bugReportLine, $file, $lineNum, $message,
		$severity, $code, $inputFile);
	$first_report = 0;
    }
}


sub RegisterBugPath {
    my ($bugReportLine, $inputFile) = @_;

    return if $first_report == 1;

    if (defined $tempBug)  {#Store the information for prev bug trace
	my ($bugLineStart, $bugLineEnd);
	if ($traceStartLine eq $bugReportLine - 1)  {
	    $bugLineStart = $traceStartLine;
	    $bugLineEnd   = $traceStartLine;
	}  else  {
	    $bugLineStart = $traceStartLine;
	    $bugLineEnd   = $bugReportLine - 1;
	}
	$tempBug->setBugLine($bugLineStart, $bugLineEnd);
	$tempBug->setBugBuildId($buildId);
	$tempBug->setBugReportPath($tempInputFile);
	$traceStartLine = $bugReportLine;
    }

    if (defined $tempBug)  {
	$xmlWriterObj->writeBugObject($tempBug);
    }
}


sub CreateBugObject {
    my ($bugReportLine, $file, $lineNum, $message, $severity, $code, $inputFile) = @_;

    #Store the information for prev bug trace
    RegisterBugPath($bugReportLine, $inputFile);

    #New Bug Instance
    my $methodId   = 0;
    my $locationId = 0;
    my $bug = new bugInstance($xmlWriterObj->getBugId());
    $bug->setBugMessage($message);
    if (defined $code && $code ne '')  {
	$bug->setBugCode($code);
    }
    if (defined $severity && $severity ne '')  {
	$bug->setBugSeverity($severity);
    }

    $bug->setBugLocation(++$locationId, "", $file, $lineNum, $lineNum,
	    0, 0, "", "true", "true");

    undef $tempBug;
    return $bug;
}


sub SetResolutionMsg {
    my ($res_msg) = @_;

    if (defined $tempBug)  {
	$tempBug->setBugSuggestion($res_msg);
    }
}


sub SetURLText {
    my ($url_txt) = @_;

    if (defined $tempBug)  {
	$tempBug->setURLText($url_txt);
    }
}


sub SetColumnNumber {
    my ($column) = @_;

    if (defined $tempBug)  {
	$tempBug->setBugColumn($column, $column, 1);
    }
}


sub SplitString {
    my ($str) = @_;

    $str =~ s/::+/~#~/g;
    my @tokens = split(':', $str, 4);
    my @ret;
    foreach $a (@tokens)  {
	#                print $a, "\n";
	$a =~ s/~#~/::/g;
	push(@ret, $a);
    }
    return (@ret);
}
