#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
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

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

my $twig = XML::Twig->new(
	twig_roots    => {'package' => 1},
	twig_handlers => {'class'   => \&parseMetric}
);

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $buildId = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub parseMetric
{
    my ($tree, $elem) = @_;

    my $bugXpath = $elem->path();

    my $bug = GetXMLObject($elem, $xmlWriterObj->getBugId(), $bugXpath);
    $elem->purge() if defined $elem;

    $xmlWriterObj->writeBugObject($bug);
}


sub GetXMLObject
{
    my ($elem) = @_;

    my $className = $elem->att('name');
    my @children  = $elem->children;
    my $file      = shift @children;
    my $fileName  = $file->att('name');

    for my $ch (@children)  {
	my $name  = $ch->att('name');
	my $ccn   = $ch->att('ccn');
	my $ccn2  = $ch->att('ccn2');
	my $cloc  = $ch->att('cloc');
	my $eloc  = $ch->att('eloc');
	my $lloc  = $ch->att('lloc');
	my $loc   = $ch->att('loc');
	my $ncloc = $ch->att('ncloc');
	my $npath = $ch->att('npath');

        #print "$name: $ccn, $ccn2, $cloc, $eloc, $lloc, $loc, $ncloc, $npath \n"
    }

    # TODO: Populate Metric Object

    $bug->setBugMessage($message);
    $bug->setBugCode($sourceRule);
    return $bug;
}
