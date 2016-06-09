#!/usr/bin/perl -w
use strict;
use warnings;
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

my $twig = XML::Twig->new(twig_roots => {'files/file' => \&metrics});

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my %h;
my $count = 0;
my $tempInputFile;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $tempInputFile = $inputFile;
    $buildId = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeMetricObjectUtil(\%h);
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub metrics {
    my ($twig, $rev) = @_;

    my $root  = $twig->root;
    my @nodes = $root->descendants;
    my $line  = $twig->{twig_parser}->current_line;
    my $col   = $twig->{twig_parser}->current_column;

    foreach my $n (@nodes)  {
	my $comment    = $n->{'att'}->{'comment'};
	my $code       = $n->{'att'}->{'code'};
	my $blank      = $n->{'att'}->{'blank'};
	my $total      = $comment + $code + $blank;
	my $sourcefile = $n->{'att'}->{'name'};
	my $language   = $n->{'att'}->{'language'};
	$h{$sourcefile}{'func-stat'}                             = {};
	$h{$sourcefile}{'file-stat'}{'file'}                     = $sourcefile;
	$h{$sourcefile}{'file-stat'}{'location'}{'startline'}    = "";
	$h{$sourcefile}{'file-stat'}{'location'}{'endline'}      = "";
	$h{$sourcefile}{'file-stat'}{'metrics'}{'code-lines'}    = $code;
	$h{$sourcefile}{'file-stat'}{'metrics'}{'blank-lines'}   = $blank;
	$h{$sourcefile}{'file-stat'}{'metrics'}{'comment-lines'} = $comment;
	$h{$sourcefile}{'file-stat'}{'metrics'}{'total-lines'}   = $total;
	$h{$sourcefile}{'file-stat'}{'metrics'}{'language'}      = $language;
    }
}
