#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use 5.010;

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

my @parsed_summary = Util::ParseSummaryFile($summary_file);
my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser(@parsed_summary);
my @build_id_arr = Util::GetBuildIds(@parsed_summary);
undef @parsed_summary;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

my $count = 0;

foreach my $input_file (@input_file_arr) {
	$build_id = $build_id_arr[$count];
    $count++;
    open my $file, "$input_dir/$input_file" or die ("Unable to open file $input_dir/$input_file");
    state $counter = 0;
    my %h;

    while ( my $line = <$file> ) {
    	if ($line =~ /flog total/) {
            my @fields = split /:/, $line;
            $h{'summary'}{'total'} = $fields[0];
            $h{'summary'}{'location'} = $.;
            $xmlWriterObj->writeMetricObject($h{'summary'});
        }
        elsif ($line =~ /method average/) {
            my @fields = split /:/, $line;
            $h{'summary'}{'average'} = $fields[0];
            $h{'summary'}{'location'} = $.;
            $xmlWriterObj->writeMetricObject($h{'summary'});
        }
        elsif ($line =~/^$/) {
            #Ignore Empty Lines
        }
        elsif ($line =~ /none/) {
            $h{'none'}{'location'} = $.;
            my @fields = split /:/, $line;
            $h{'none'}{'CCN'} = $fields[0];
            $xmlWriterObj->writeMetricObject($h{'none'});
        }
        else {
            $line =~ /(\d+\.\d+):\s+([A-Za-z:]+)\#(\w+).*:(\d+)/;
            $h{ $3 }{'CCN'} = $1;
            $h{ $3 }{'line'} = $4;
            $h{ $3 }{'location'} = $.;
            $xmlWriterObj->writeMetricObject($h{$3});
        }
        $counter++;
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}