#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin";
use Getopt::Long;
use Cwd qw();
use File::Basename;
use XML::Twig;
use IO qw(File);
use XML::Writer;
use Util;
#use Memory::Usage;

my $current_dir = Cwd::cwd();
my $script_dir = dirname(Cwd::abs_path($0)) ;
my ($summaryFile, $in_dir, $out_dir, $outputFile, $help, $version, $logfile,
	$weaknessCountFile, $reportSummaryFile, $merge);

#my $mu = Memory::Usage->new();
#$mu->record('Before XML Parsing');

GetOptions(
           "summary_file=s" => \$summaryFile, 
           "input_dir=s" => \$in_dir,
           "output_dir=s" => \$out_dir,
           "output_file=s" => \$outputFile,
           "help" => \$help,
           "version" => \$version,
           "merge!" => \$merge,
           "log_file=s" => \$logfile,
           "weakness_count_file=s" => \$weaknessCountFile,
           "report_summary_file=s" => \$reportSummaryFile
      ) or &usage() and die ("Error parsing command line arguments\n");

usage() if defined $help;
version() if defined $version;

$out_dir = (defined $out_dir) ? $out_dir : $current_dir;
$summaryFile = (defined $summaryFile) ? $summaryFile : "$current_dir/assessment_summary.xml";

$in_dir = (defined $in_dir) ? $in_dir : $current_dir;
$outputFile = (defined $outputFile)
	? ((Util::IsAbsolutePath($outputFile) eq 0) ? "$out_dir/$outputFile" : "$outputFile")
	: "$out_dir/parsed_results.xml";

if (defined $weaknessCountFile)  {
    $weaknessCountFile = (Util::IsAbsolutePath($weaknessCountFile) eq 0)
	    ? "$out_dir/$weaknessCountFile" : "$weaknessCountFile";
    Util::TestPath($weaknessCountFile, "W");
} else {
    print "\nNo weakness count file, proceeding without the file\n";
}

if (defined $reportSummaryFile)  {
    $reportSummaryFile = (Util::isAbsolutePath($reportSummaryFile) eq 0)
	    ? "$out_dir/$reportSummaryFile" : "$reportSummaryFile";
    Util::TestPath($reportSummaryFile, "W");
}

print "SCRIPT_DIR: $script_dir\n";
print "CURRENT_DIR: $current_dir\n";
print "SUMMARY_FILE: $summaryFile\n";
print "INPUT_DIR: $in_dir\n";
print "OUTPUT_DIR: $out_dir\n";
print "OUTPUT_FILE: $outputFile\n";

my $toolName = Util::GetToolName($summaryFile);

executeParser($toolName);
#$mu->record('After XML parsing');
#$mu->dump();


sub executeParser
{
    my ($toolName) = @_;

    my @execString = ("perl", $script_dir."/".$toolName.".pl", "--tool_name=$toolName", "--summary_file=$summaryFile", "--output_file=$outputFile", "--input_dir=$in_dir", "--weakness_count_file=$weaknessCountFile");
    exec @execString;
}


sub version
{
    system ("cat $script_dir/version.txt");
    exit 0;
}


sub usage
{
    print <<EOF;
Usage: resultParser.pl [-h] [-v]
          [--summary_file=<PATH_TO_SUMMARY_FILE>]
          [--input_dir=<PATH_TO_RESULTS_DIR>]
          [--output_dir=<PATH_TO_OUTPUT_DIR>]
          [--output_file=<OUTPUT_FILENAME>]
          [--weakness_count_file=<WEAKNESS_COUNT_FILENAME>]
          [--merge/nomerge]
          [--log_file=<LOGFILE>]
          [--report_summary_file=<REPORT_SUMMARY_FILE>]

Arguments
    -h, --help                          show this help message and exit
    -v, --version                       show the version number
    --summary_file=[SUMMARY_FILE]       Path to the Assessment Summary File
    --input_dir=[INPUT_DIR]             Path to the raw assessment result directory
    --output_dir=[OUTPUT_DIR]           Path to the output directory
    --output_file=[OUTPUT_FILE]         Output File name in merged case 
                                          (relative to the output_dir)
    --merge                     Merges the parsed result in a single file (Default option)
    --nomerge                           Do not merge the parsed results
    --weakness_count_file               Name of the weakness count file
                                          (relative to the output_dir)
    --log_file                          Name of the log file
EOF

    exit 0;
}
