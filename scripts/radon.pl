#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use JSON;
use xmlWriterObject;
use Util;
use 5.010;

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

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
    state counter = 0;
    my $json;
    {
    	local $/;
        open my $fh, "<", "$input_dir/$input_file";
        $json = <$fh>;
        close $fh;
    }
    my $data = decode_json($json);
    my $k = (keys %{ $data })[0];
    my @records = @{ $data->{ $k } };
    foreach my $v ( @records ) {
    	my %h;
        $h{ $counter }{'name'} = $v->{"name"};
        $h{ $counter }{'col_offset'} =  $v->{"col_offset"};
        $h{ $counter }{'rank'} = $v->{"rank"};
        $h{ $counter }{'classname'} = $v->{"classname"};
        $h{ $counter }{'complexity'} = $v->{"complexity"};
        $h{ $counter }{'lineno'} = $v->{"lineno"};
        $h{ $counter }{'endline'} = $v->{"endline"};
        $h{ $counter }{'type'} = $v->{"type"};
        $xmlWriterObj->writeMetricObject( $h{ $counter } );
        $counter++;
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();