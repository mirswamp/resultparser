#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my (
    $input_dir,  $output_file,  $tool_name, $summary_file
);

GetOptions(
    "input_dir=s"   => \$input_dir,
    "output_file=s"  => \$output_file,
    "tool_name=s"    => \$tool_name,
    "summary_file=s" => \$summary_file
) or die("Error");

if( !$tool_name ) {
    $tool_name = Util::GetToolName($summary_file);
}

my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser($summary_file);

my $file_xpath_stdviol='ResultsSession/CodingStandards/StdViols/StdViol';
my $file_xpath_dupviol='ResultsSession/CodingStandards/StdViols/DupViol';
my $file_xpath_flowviol='ResultsSession/CodingStandards/StdViols/FlowViol'; 

my $twig = XML::Twig->new(
    twig_handlers      => { $file_xpath_stdviol => \&parseViolations_stdviol,
                    $file_xpath_dupviol => \&parseViolations_dupviol,
                    $file_xpath_flowviol => \&parseViolations_flowviol }
);


#Initialize the counter values
my $bugId       = 0;
my $file_Id     = 0;
my $file_path = "";

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
