#!/usr/bin/perl -w

use strict;
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
	"weakness_count_file=s" => \$weakness_count_file,
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

my $count = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my $temp_input_file;

foreach my $input_file (@input_file_arr) {
    $temp_input_file = $input_file;
    my $json_data;
    $build_id = $build_id_arr[$count];
    $count++;
    {
	open FILE, "$input_dir/$input_file"
		or die "open $input_dir/$input_file.: $!";
	local $/;
	$json_data = <FILE>;
	close FILE or die "close $input_dir/$input_file: $!";
    }

    my $json_object = JSON->new->utf8->decode($json_data);
    my $app_path = $json_object->{"scan_info"}->{"app_path"};
    
$app_path =~ s/^\Q$package_name\E\///;
    foreach my $warning ( @{ $json_object->{"warnings"} } ) {
	my $file = $app_path."/".$warning->{"file"};

	my $bug_object = new bugInstance( $xmlWriterObj->getBugId() );

	if ( defined( $warning->{"line"} ) ) {
	    my $line = $warning->{"line"};
	    $bug_object->setBugLocation( 1, "", $file, $line, $line, 0, 0, "",
		    "true", "true" );
	}
	else {
	    $bug_object->setBugLocation( 1, "", $file, 0, 0, 0, 0, "", "true",
		    "true" );
	}

	if ( defined( $warning->{"location"} ) ) {
	    if ( $warning->{"location"}{"type"} eq "method" ) {
		my $class  = $warning->{"location"}{"class"};
		my $method = $warning->{"location"}{"method"};
		$method =~ s/$class.//;
		$bug_object->setBugMethod( 1, $class, $method, "true" );
		$bug_object->setClassName( $warning->{"location"}{"class"} );
	    }
	}

	$bug_object->setBugMessage(
		sprintf( "%s (%s)", $warning->{"message"}, $warning->{"link"} ) );
	$bug_object->setBugCode( $warning->{"warning_type"} );
	$bug_object->setBugSeverity( $warning->{"confidence"} );
	$bug_object->setBugWarningCode( $warning->{"warning_code"} );
	$bug_object->setBugToolSpecificCode( $warning->{"code"} );
	$bug_object->setBugReportPath($temp_input_file);
	$xmlWriterObj->writeBugObject($bug_object);
    }
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
	Util::PrintWeaknessCountFile( $weakness_count_file,
		$xmlWriterObj->getBugId() - 1 );
}

