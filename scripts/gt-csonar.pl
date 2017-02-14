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
my @warningData;

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
my ($line, $bugGroup, $bugCode, $filename, $method, $bugMsg, $file);
my @weaknessCategories;
my %buglocation_hash;
my $resultsDir = $inputDir;
$resultsDir = '.' if $resultsDir eq '';

foreach my $inputFile (@inputFiles)  {
    my $resultFile = "$inputDir/$inputFile";
    if (-f $resultFile)  {
	if ($resultFile =~ /^(.*)\/.*?$/)  {
	    $resultsDir = $1;
	}  else  {
	    $resultsDir = '.';
	}
	my $analysisTwig = XML::Twig->new(
		twig_handlers => {
		    'analysis/warning'	=> \&ProcessAnalysis
		}
	    );
	$analysisTwig->parsefile($resultFile);
    }  elsif (-d $resultFile)  {
	# old CodeSonar runs set this to the result directory
	# score is undefined in this case
	opendir DIR, $resultsDir or die "opendir $resultsDir: $!";
	while (readdir(DIR))  {
	    my $file = $_;
	    next unless -f $file && $file =~ /\.xml$/;
	    my $r = { file => $file, score => undef };
	    push @warningData, $r;
	}
	closedir DIR or die "closedir $resultsDir";
    }  else  {
	die "Result file 'resultFile' not found";
    }
}

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $warning (@warningData)  {
    my $inputFile = $warning->{file};
    my $score = $warning->{score};
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    $eventNum	 = 1;
    $bugMsg = "";
    undef($method);
    undef(@weaknessCategories);
    undef($filename);
    undef($bugGroup);
    undef($bugCode);
    undef($line);
    my $file = "$resultsDir/$inputFile";
    my $filterCmd = "iconv -f ISO-8859-15 -t US-ASCII -c $file | tr -c '\\11\\12\\15\\40-\\176' ' '";
    print "Filtering CodeSonar XML files to fix invalid XML:\n    $filterCmd\n";
    open my $filteredInput, '-|', $filterCmd or die "open -| $filterCmd: $!";
    $twig->parse($filteredInput);
    my @cwes;
    foreach my $c (@weaknessCategories)  {
	if ($c =~ /^\s*cwe:(\d+)\s*$/i)  {
	    push @cwes, $1;
	}
    }
    my $cwe;
    $cwe = $cwes[0] if @cwes;
    my $bug = new bugInstance($xmlWriterObj->getBugId());
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($score) if defined $score;
    $bug->setBugGroup($bugGroup);
    $bug->setBugCode($bugCode);
    $bug->setCweId($cwe) if defined $cwe;
    $bug->setBugReportPath($tempInputFile);
    $bug->setBugBuildId($buildId,);
    $bug->setBugMethod(1, "", $method, "true");
    $bug->setCWEArray(@weaknessCategories);
    my @events = sort {$a <=> $b} (keys %buglocation_hash);

    foreach my $elem (sort {$a <= $b} @events)  {
	my $primary = ($elem eq $events[$#events]) ? "true" : "false";
	my @tokens = split(":", $buglocation_hash{$elem}, 3);
	$bug->setBugLocation(
	    $elem, "", $tokens[0], $tokens[1],
	    $tokens[1], "0", "0", $tokens[2],
	    $primary, "true"
	);
    }
    $xmlWriterObj->writeBugObject($bug);
    %buglocation_hash = ();
    close $filteredInput or die "close -| $filteredInput: $! (?=$?)";
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}



sub ProcessAnalysis
{
    my ($tree, $elem) = @_;
    my $url = $elem->att('url');
    my @scores = $elem->children('score');
    my $score;
    if (@scores >= 1)  {
	$score = $scores[0]->text();
	if (@scores > 1)  {
	    print STDERR "analysis XML file (url=$url) contains more than 1 score element\n";
	}
	if ($score !~ /\d+/)  {
	    print STDERR "analysis XML (url=$url) score, '$score' is not numeric\n";
	}  elsif ($score < 0 or $score > 100)  {
	    print STDERR "analysis XML (url=$url) score, '$score' is not 0-100\n";
	}
    }  else  {
	print STDERR "analysis XML file (url=$url) contain no score element\n";
    }

    my $file = $url;
    $file =~ s/^\/?(.*?)(\?.*)?$/$1/;

    my $r = { file => $file, score => $score };
    push @warningData, $r;

    $tree->purge();
}


sub GetFileDetails
{
    my ($tree, $elem) = @_;
    $line      = $elem->att('line_number');
    $bugGroup   = $elem->att('significance');
    $bugCode   = $elem->att('warningclass');
    $filename = Util::AdjustPath($packageName, $cwd, $elem->att('filename'));
    $method = $elem->att('procedure');
}


sub GetCWEDetails
{
    my ($tree, $elem) = @_;

    foreach my $cwe ($elem->children('category'))  {
	push(@weaknessCategories, $cwe->text);
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
