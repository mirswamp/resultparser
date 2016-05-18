#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Cwd qw();
use File::Basename;
use XML::Twig;
use IO qw(File);
use XML::Writer;
use Util;
#use Memory::Usage;

my $current_dir = Cwd::cwd();
my $script_dir = dirname(Cwd::abs_path($0 ) ) ;
my ($summary_file,$in_dir,$out_dir,$output_file,$help,$version,$logfile,$weakness_count_file,$report_summary_file, $merge );

#my $mu = Memory::Usage->new();
#$mu->record('Before XML Parsing');

GetOptions(
           "summary_file=s" => \$summary_file, 
           "input_dir=s" => \$in_dir,
           "output_dir=s" => \$out_dir,
           "output_file=s" => \$output_file,
           "help" => \$help,
           "version" => \$version,
           "merge!" => \$merge,
           "log_file=s" => \$logfile,
           "weakness_count_file=s" => \$weakness_count_file,
           "report_summary_file=s" => \$report_summary_file
      ) or &usage() and die ("Error parsing command line arguments\n" );

usage() if defined ( $help );
version() if defined ( $version );

$out_dir = defined ($out_dir ) ? $out_dir : $current_dir;
$summary_file = defined ($summary_file) ? $summary_file : "$current_dir/assessment_summary.xml";

$in_dir = defined ($in_dir) ? $in_dir : $current_dir;
$output_file = defined ($output_file ) ? ((Util::IsAbsolutePath( $output_file ) eq 0 ) ? "$out_dir/$output_file":"$output_file" ) : "$out_dir/parsed_assessment_report.xml";

if ( defined ( $weakness_count_file ) ) {
    $weakness_count_file = ( Util::IsAbsolutePath($weakness_count_file ) eq 0 ) ? "$out_dir/$weakness_count_file" : "$weakness_count_file";
    Util::TestPath($weakness_count_file ,"W" );
} else {
    print "\nNo weakness count file, proceeding without the file\n";
}

if(defined( $report_summary_file)) {
    $report_summary_file = (Util::isAbsolutePath($report_summary_file ) eq 0) ? "$out_dir/$report_summary_file" : "$report_summary_file";
    Util::TestPath($report_summary_file ,"W" );
}

print "SCRIPT_DIR: $script_dir\n";
print "CURRENT_DIR: $current_dir\n";
print "SUMMARY_FILE: $summary_file\n";
print "INPUT_DIR: $in_dir\n";
print "OUTPUT_DIR: $out_dir\n";
print "OUTPUT_FILE: $output_file\n";

my $tool_name = Util::GetToolName($summary_file);

executeParser($tool_name);
#$mu->record('After XML parsing');
#$mu->dump();

sub executeParser
{
    my ($tool_name) = @_;
    my @execString = ("perl",$script_dir."/".$tool_name.".pl", "--tool_name=$tool_name","--summary_file=$summary_file", "--output_file=$output_file", "--input_dir=$in_dir", "--weakness_count_file=$weakness_count_file");
    my $out = system(@execString);
}

#############################################################################################################################################################################################################################################

sub version
{
    system ("cat $script_dir/version.txt" );
    exit 0;
}


sub usage
{
print "Usage: resultParser.pl [-h] [-v]
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
    --summary_file=[SUMMARY_FILE]                   Path to the Assessment Summary File
    --input_dir=[INPUT_DIR]                         Path to the raw assessment result directory
    --output_dir=[OUTPUT_DIR]                       Path to the output directory
    --output_file=[OUTPUT_FILE]                     Output File name in merged case 
                            (relative to the output_dir)
    --merge                     Merges the parsed result in a single file (Default option)
    --nomerge                                       Do not merge the parsed results
    --weakness_count_file                           Name of the weakness count file
                            (relative to the output_dir)
    --log_file                                      Name of the log file
    exit 0;"
}

