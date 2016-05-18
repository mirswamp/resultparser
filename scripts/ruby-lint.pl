#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

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

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;
my $count   = 0;

my %severity_hash = ( 'W' => 'warning', 'I' => 'info', 'E' => 'error' );

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my $temp_input_file;

foreach my $input_file (@input_file_arr) {
    $temp_input_file = $input_file;
    $build_id = $build_id_arr[$count];
    $count++;
    open( my $fh, "<", "$input_dir/$input_file" )
      or die "Could not open the input file : $!";
    while (<$fh>) {
	my $curr_line   = $_;
	my @tokens      = split( /:/, $curr_line, 5 );
	my $file        = Util::AdjustPath( $package_name, $cwd, $tokens[0] );
	my $severity    = $severity_hash{ $tokens[1] };
	my $line        = $tokens[2];
	my $column      = $tokens[3];
	my $bug_message = $tokens[4];
	chomp($bug_message);
	my $bug_code   = BugCode($bug_message);
	my $bug_object = new bugInstance( $xmlWriterObj->getBugId() );
	$bug_object->setBugLocation(
		1,       "", $file,  $line, $line, $column,
		$column, "", 'true', 'true'
	);
	$bug_object->setBugMessage($bug_message);
	$bug_object->setBugSeverity($severity);
	$bug_object->setBugCode($bug_code);
	$bug_object->setBugBuildId($build_id);
	$bug_object->setBugReportPath(
		Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ) );
	$xmlWriterObj->writeBugObject($bug_object);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
    Util::PrintWeaknessCountFile( $weakness_count_file,
	    $xmlWriterObj->getBugId() - 1 );
}

sub BugCode {
    my $bugmessage = shift;
    if ( $bugmessage =~ /Comparing/ ) {
	return 'UselessEqualityChecks';
    }
    elsif ( $bugmessage =~ /unused/ ) {
	return 'UnusedVariables';
    }
    elsif ( $bugmessage =~ /undefined method/ ) {
	return 'UndefinedMethods';
    }
    elsif ( $bugmessage =~ /undefined/ ) {
	return 'UndefinedVariables';
    }
    elsif ( $bugmessage =~ /shadowing outer/ ) {
	return 'ShadowingVariables';
    }
    elsif ( $bugmessage =~ /can only be used inside/ ) {
	return 'LoopKeywords';
    }
    elsif ( $bugmessage =~ /wrong number of arguments/ ) {
	return 'ArgumentAmount';
    }
    return $bugmessage;
}
