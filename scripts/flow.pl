#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

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
	$build_id = $build_id_arr[$count];
	$count++;
	my $json_data;
	{
		open FILE, "$input_dir/$input_file" or die "open $input_file: $!";
		local $/;
		$json_data = <FILE>;
		close FILE or die "close $input_file: $!";
	}

	my $json_object = JSON->new->utf8->decode($json_data);

	foreach my $error ( @{ $json_object->{"errors"} } ) {
		GetFlowObject( $error, $xmlWriterObj->getBugId() );
	}
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
	Util::PrintWeaknessCountFile( $weakness_count_file,
		$xmlWriterObj->getBugId() - 1 );
}

sub GetFlowObject() {
	my $e             = shift;
	my $bug_id        = shift;
	my $error_message = "";
	my @messages      = @{ $e->{"message"} };
	my $bug_code = "";
	foreach my $msg ( @{ $e->{"message"} } ) {
		if ( $error_message eq "" ) {
			$error_message .= $msg->{"descr"};
		}
		else {
			$error_message .= " ".$msg->{"descr"};
		}
		if($msg->{"type"} eq "Comment"){
			$bug_code = $msg->{"descr"};
		}
	}
	if($bug_code eq ""){
		$bug_code = $messages[0]->{"descr"};
	}
	my $file;
	my $loc_arr = $messages[0]->{"loc"};
	$file = $loc_arr->{"source"};
	my $bug_object = new bugInstance($bug_id);

	my $startline = $messages[0]->{"start"};
	my $endline   = $messages[0]->{"end"};
	$bug_object->setBugLocation( 1, "", $file, $startline, $endline, 0, 0, "",
		"true", "true" );

	$bug_object->setBugMessage($error_message);
	$bug_object->setBugCode($bug_code);
	$bug_object->setBugSeverity( $e->{"level"} );
	$bug_object->setBugGroup( $e->{"level"} );
	$xmlWriterObj->writeBugObject($bug_object);
}
