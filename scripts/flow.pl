#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

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

foreach my $input_file ( @input_file_arr ) {
	my $json_data;
	{
		open FILE, "$input_dir/$input_file" or die "open $input_file: $!";
		local $/;
		$json_data = <FILE>;
		close FILE or die "close $input_file: $!";
	}
	
	my $json_object = JSON->new->utf8->decode($json_data);
	
	foreach my $error (@{ $json_object->{"errors"} }) {
		foreach my $msg ( @{ $error->{"message"} } ) {
			my $bug_object = GetFlowObject($msg, $xmlWriterObj->getBugId());
			$xmlWriterObj->writeBugObject($bug_object);
		}
	}
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub GetFlowObject() {
	my $e = shift;
	my $bug_id = shift;
	my $file = $package_name . "/" . $e->{"path"};
	
	my $bug_object = new bugInstance($bug_id);

	my $startline = $e->{"start"};
	my $endline = $e->{"end"};
	$bug_object->setBugLocation(1, "", $file, $startline, $endline, 0, 0, "", "true", "true");

	$bug_object->setBugMessage($e->{"descr"});
	$bug_object->setBugCode($e->{"descr"});
	$bug_object->setBugSeverity($e->{"level"});
	$bug_object->setBugGroup($e->{"level"});
	return $bug_object;
}