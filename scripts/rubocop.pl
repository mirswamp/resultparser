#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

my (
    $input_dir,  $output_file,  $tool_name, $summary_file, $weakness_count_file, $help, $version
);

GetOptions(
    "input_dir=s"   => \$input_dir,
    "output_file=s"  => \$output_file,
    "tool_name=s"    => \$tool_name,
    "summary_file=s" => \$summary_file,
    "weakness_count_file=s" => \$$weakness_count_file,
    "help" => \$help,
    "version" => \$version
) or die("Error");

Util::Usage() if defined ( $help );
Util::Version() if defined ( $version );

if( !$tool_name ) {
    $tool_name = Util::GetToolName($summary_file);
}

my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser($summary_file);

my %severity_hash =  (R => 'refactor', C => 'convention', W => 'warning', E => 'error', F => 'fatal');

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
    open ( my $fh, "<", "$input_dir/$input_file" ) or die "Could not open the input file $!";
    while(<$fh>){
    	my $curr_line = $_;
    	chomp($curr_line);
        my ($file, $line, $column, $severity, $bugcode, $bugmessage) = $curr_line =~ /(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*:\s*(.*?)\s*:\s*(.*)/;

        $file = Util::AdjustPath($package_name, $cwd, $file);
        $severity = $severity_hash{$severity};
        
        my $bugObj = new bugInstance($xmlWriterObj->getBugId());
        $bugObj->setBugLocation(1,"",$file,$line,$line,$column,$column,"",'true','true');
        $bugObj->setBugMessage($bugmessage);
        $bugObj->setBugSeverity($severity);
        $bugObj->setBugCode($bugcode);
        $bugObj->setBugBuildId($build_id);
        $bugObj->setBugReportPath($input_file);
        $xmlWriterObj->writeBugObject($bugObj);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();