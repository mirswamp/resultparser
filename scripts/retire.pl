#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

my ( $input_dir, $output_file, $tool_name, $summary_file, $weakness_count_file );

GetOptions(
	"input_dir=s"    => \$input_dir,
	"output_file=s"  => \$output_file,
	"tool_name=s"    => \$tool_name,
	"summary_file=s" => \$summary_file,
	"weakness_count_file=s" => \$weakness_count_file
) or die("Error");

if ( !$tool_name ) {
	$tool_name = Util::GetToolName($summary_file);
}

my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser($summary_file);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	my $json_data;
	{
		open FILE, "$input_dir/$input_file" or die "open $input_dir/$input_file.: $!";
		local $/;
		$json_data = <FILE>;
		close FILE or die "close $input_dir/$input_file: $!";
	}

	my @data = @{decode_json($json)};
	foreach my $arr (@data) {
		my $bug_object = new bugInstance($bug_id);
		my $jt = $arr;
		my $file = $jt->{"file"};
		my @results = $jt->{"results"};
		my $r = $results[0][0];
		my $component = $r->{"component"};
		my $detection = $r->{"detection"};
		my $version = $r->{"version"};
		my @vulns = $r->{"vulnerabilities"}[0];
		foreach my $v (@vulns) {
			my $sev = $v->{"severity"};
			my $identifiers = $v->{"identifiers"};
			if (exists $identifiers->{"summary"}) {
				my $summary = $identifiers->{"summary"};
			}
			if (exists $identifiers->{"bug"}) {
				my $bug = $identifiers->{"bug"};
			}
			if (exists $identifiers->{"CVE"}) {
				my @cve = $identifiers->{"CVE"};
				my $cv = $cve[0][0];
			}
		}
		#FIXME: Decide BugObject Population
		my $bug_object = new bugInstance( $xmlWriterObj->getBugId() );
		$xmlWriterObj->writeBugObject($bug_object);
	}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

}

if(defined $weakness_count_file){
	Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}
