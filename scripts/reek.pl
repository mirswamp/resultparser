#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ( $input_dir, $output_file, $tool_name, $summary_file );

GetOptions(
	"input_dir=s"    => \$input_dir,
	"output_file=s"  => \$output_file,
	"tool_name=s"    => \$tool_name,
	"summary_file=s" => \$summary_file
) or die("Error");

if ( !$tool_name ) {
	$tool_name = Util::GetToolName($summary_file);
}

my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser($summary_file);

if ( $input_file_arr[0] =~ /\.json$/ ) {
	foreach my $input_file (@input_file_arr) {
		ParseJsonOutput($input_file);
	}
}
elsif ( $input_file_arr[0] =~ /\.xml$/ ) {
	my $twig = XML::Twig->new(
		twig_roots         => { 'file'  => 1 },
		start_tag_handlers => { 'file'  => \&setFileName },
		twig_handlers      => { 'error' => \&parseViolations }
	);
}
