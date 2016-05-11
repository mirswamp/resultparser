#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use JSON;
use xmlWriterObject;
use Util;
use 5.010;

my ( $input_dir, $output_file, $tool_name, $summary_file, $weakness_count_file,
	$help, $version );

GetOptions(
	"input_dir=s"           => \$input_dir,
	"output_file=s"         => \$output_file,
	"tool_name=s"           => \$tool_name,
	"summary_file=s"        => \$summary_file,
	"weakness_count_file=s" => \$$weakness_count_file,
	"help"                  => \$help,
	"version"               => \$version
) or die("Error");

Util::Usage()   if defined($help);
Util::Version() if defined($version);

if ( !$tool_name ) {
	$tool_name = Util::GetToolName($summary_file);
}

my @parsed_summary = Util::ParseSummaryFile($summary_file);
my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser(@parsed_summary);
my @build_id_arr = Util::GetBuildIds(@parsed_summary);
undef @parsed_summary;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my $count = 0;

foreach my $input_file (@input_file_arr) {
	state counter = 0;
	$build_id = $build_id_arr[$count];
	$count++;
	my $json;
	{
		local $/;
		open my $fh, "<", "$input_dir/$input_file";
		$json = <$fh>;
		close $fh;
	}
	my $data    = decode_json($json);
	my $k       = ( keys %{$data} )[0];
	my @records = @{ $data->{$k} };
	foreach my $v (@records) {
		my %h;
		$h{$counter}{'name'}       = $v->{"name"};
		$h{$counter}{'col_offset'} = $v->{"col_offset"};
		$h{$counter}{'rank'}       = $v->{"rank"};
		$h{$counter}{'classname'}  = $v->{"classname"};
		$h{$counter}{'complexity'} = $v->{"complexity"};
		$h{$counter}{'lineno'}     = $v->{"lineno"};
		$h{$counter}{'endline'}    = $v->{"endline"};
		$h{$counter}{'type'}       = $v->{"type"};
		$xmlWriterObj->writeMetricObject( $h{$counter} );
		$counter++;
	}
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
