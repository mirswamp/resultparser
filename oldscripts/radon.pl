#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use JSON;
use xmlWriterObject;
use Util;
use 5.010;

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

    my $json;
    {
	local $/;
	open my $fh, "<", "$inputDir/$inputFile";
	$json = <$fh>;
	close $fh;
    }
    my $data    = decode_json($json);

    foreach my $file (keys %$data)  {
	my $refType = ref $data->{$file};
	if ($refType ne 'ARRAY')  {
	    #
	    # "FILE-NAME": {"error": "ERR-MSG"}
	    #
	    # "/home/kupsch/build/pkg1/luigi-1.0.20/build/lib/luigi/hive.py":
	    # 		{"error": "invalid syntax (<unknown>, line 211)"}
	    #
	    print STDERR "WARNING: _{$file} is $refType, expected 'ARRAY', ignoring\n";
	    next;
	}
	foreach my $object (@{$data->{$file}})  {
	    my $type = $object->{type};
	    my $class = '';
	    my $startline = $object->{lineno};
	    my $endline = $object->{endline};
	    if ($type ne 'function')  {
		$class = $object->{$type eq 'class' ? 'name' : 'classname'};
	    }
	    my $function = ($type eq 'class') ? '' : $object->{name};
	    my %m = (
		    file		=> $file,
		    class		=> $class,
		    function		=> $function,
		    location		=> {
					    startline		=> $startline,
					    endline		=> $endline,
					},
		    metrics		=> {},
	    );
	    $m{metrics}{'code-lines'} = $endline - $startline + 1;
	    $m{metrics}{ccn} = $object->{complexity} if exists $object->{complexity};
	    $xmlWriterObj->writeMetricObject(\%m);
	}
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}
