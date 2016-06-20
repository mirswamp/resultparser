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

my $violationId = 0;
my $bugId       = 0;
my $locationId  = 0;
my $fileId     = 0;
my $count       = 0;

my $prev_line        = "";
my $traceStartLine = 1;
my $methodId;
my $currentLineNum;
my $fnFile;
my $function;
my $line;
my $message;
my $prevMsg;
my $prevBugGroup;
my $prev_fn;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my $tempInputFile;
my $bug;

foreach my $inputFile (@inputFiles)  {
    $prevMsg         = "";
    $prevBugGroup   = "";
    $prev_fn          = "";
    $prev_line        = "";
    $traceStartLine = 1;
    $locationId       = 0;
    $methodId         = 0;
    $tempInputFile  = $inputFile;
    $buildId         = $buildIds[$count];
    $count++;

    my $input = new IO::File("<$inputDir/$inputFile");
    print "\n<$inputDir/$inputFile";
    my $fn_flag = -1;
LINE:
    while (my $line = <$input>)  {
	chomp($line);
	$currentLineNum = $.;
	if ($line eq $prev_line)  {
	    next LINE;
	}  else  {
	    $prev_line = $line;
	}
	my $valid = ValidateLine($line);
	if ($valid eq "function")  {
	    my @tokens = Util::SplitString($line);
	    $fnFile  = $tokens[0];
	    $function = $tokens[1];
	    $function =~ /‘(.*)’/;
	    $function = $1;
	    $fn_flag  = 1;
	}  elsif ($valid ne "invalid")  {
	    if ($fn_flag == 1)  {
		$fn_flag = -1;
	    }  else  {
		$function = "";
		$fnFile  = "";
	    }
	    ParseLine($currentLineNum, $line, $function, $fnFile);
	}
    }
    if (defined $bug)  {
	$xmlWriterObj->writeBugObject($bug);
	undef $bug;
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId()-1);
}


sub ParseLine {
    my ($bugReportLine, $line, $function, $fnFile) = @_;

    my @tokens        = Util::SplitString($line);
    my $num_of_tokens = @tokens;
    my ($file, $lineNum, $colNum, $bugGroup, $message);
    my $flag = 1;
    if ($num_of_tokens eq 5)  {
	$file      = Util::AdjustPath($packageName, $cwd, $tokens[0]);
	$lineNum   = $tokens[1];
	$colNum    = $tokens[2];
	$bugGroup = $tokens[3];
	$message   = $tokens[4];
    }  elsif ($num_of_tokens eq 4)  {
	$file      = Util::AdjustPath($packageName, $cwd, $tokens[0]);
	$lineNum   = $tokens[1];
	$colNum    = 0;
	$bugGroup = $tokens[2];
	$message   = $tokens[3];
    }  else  {

	#bad line. hence skipping.
	$flag = 0;
    }

    if ($flag ne 0)  {
	$bugGroup = Util::Trim($bugGroup);
	$message   = Util::Trim($message);
	RegisterBug($bugReportLine, $function, $fnFile, $file, $lineNum,
		$colNum, $bugGroup, $message);
    }
}


sub RegisterBugpath {
    my ($bugReportLine) = @_;

    my ($bugLineStart, $bugLineEnd);
    if ($bugId > 0)  {
	if ($traceStartLine eq $bugReportLine - 1)  {
	    $bugLineStart = $traceStartLine;
	    $bugLineEnd   = $traceStartLine;
	}  else  {
	    $bugLineStart = $traceStartLine;
	    $bugLineEnd   = $bugReportLine - 1;
	}
	$bug->setBugLine($bugLineStart, $bugLineEnd);
	$traceStartLine = $bugReportLine;
    }
}


sub RegisterBug {
    my ($bugReportLine, $function, $fnFile, $file, $lineNum, $colNum,
	    $bugGroup, $message) = @_;

    if ($bugGroup eq "note" and $bugId > 0)  {
	return unless defined $bug;

	$bug->setBugLocation(
		++$locationId, "", $file, $lineNum,
		$lineNum, $colNum, 0,     $message,
		"false", "true"
	);
	$prevMsg       = $message;
	$prevBugGroup = $bugGroup;
	$prev_fn        = $function;
	$xmlWriterObj->writeBugObject($bug);
	undef $bug;
	return;
    }
    if ($fnFile ne $file || $prevMsg ne $message || $prevBugGroup ne $bugGroup
	    || $prev_fn ne $function || $locationId > 99)  {
	if (defined $bug)  {
	    $xmlWriterObj->writeBugObject($bug);
	    undef $bug;
	}
	$bugId++;
	$bug = new bugInstance($bugId);
	RegisterBugpath($bugReportLine);
	undef $bugReportLine;
	$methodId   = 0;
	$locationId = 0;
	$bug->setBugBuildId($buildId);
	$bug->setBugReportPath($tempInputFile);

	if ($function ne '')  {
	    $bug->setBugMethod(++$methodId, "", $function, "true");
	}
	$bug->setBugGroup($bugGroup);
	ParseMessage($message);
    }

    $bug->setBugLocation(
	    ++$locationId, "", $file, $lineNum,
	    $lineNum, $colNum, 0,     "",
	    "true", "true"
    );
    $prevMsg       = $message;
    $prevBugGroup = $bugGroup;
    $prev_fn        = $function;
}


sub ParseMessage {
    my ($message) = @_;

    my $temp      = $message;
    my $orig_msg  = $message;
    my $code      = $message;

    if (defined $code)  {
	$code =~ /(.*)\[(.*)\]$/;
	$message = $1;
	$code    = $2;
    }

    if (!defined $code or $code eq "")  {
	$code = $temp;
	$code =~ s/(?: \d+)? of ‘.*?’//g;
	$code =~ s/^".*?" / /;
	$code =~ s/‘.*?’//g;
	$code =~ s/ ".*?"/ /g;
	$code =~ s/(?: to) ‘.*?’/ /g;
	$code =~ s/^(ignoring return value, declared with attribute).*/$1/;
	$code =~ s/^(#(?:warning|error)) .*/$1/;
	$code =~ s/cc1: warning: .*: No such file or directory/-Wmissing-include-dirs/;
    }

    if ((defined $message) && ($message ne ''))  {
	$bug->setBugMessage($message);
    }  else  {
	$bug->setBugMessage($orig_msg)
    }
    if ((defined $code) && ($code ne ''))  {
	$bug->setBugCode($code);
    }
}


sub ValidateLine {
    my ($line) = @_;

    if ($line =~ m/^.*: *In .*function.*:$/i)  {
	return "function";
    }  elsif ($line =~ m/^.*: *In .*constructor.*:$/i)  {
	return "function";
    }  elsif ($line =~ m/.*: *warning *:.*/i)  {
	return "warning";
    }  elsif ($line =~ m/.*: *error *:.*/i)  {
	return "error";
    }  elsif ($line =~ m/.*: *note *:.*/i)  {
	return "note";
    }  else  {
	return "invalid";
    }
}
