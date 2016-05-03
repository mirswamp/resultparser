#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use JSON;

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
		open FILE, "$input_dir/$input_file"
		  or die "open $input_dir/$input_file.: $!";
		local $/;
		$json_data = <FILE>;
		close FILE or die "close $input_dir/$input_file: $!";
	}

	my $json_object = JSON->new->utf8->decode($json_data);

	foreach my $warning ( @{ $json_object->{"warnings"} } ) {
		print "Warning reached\n";
		my $file       = $package_name . "/" . $warning->{"file"};

		my $bug_object = new bugInstance($xmlWriterObj->getBugId());

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
				$bug_object->setBugMethod(
					1,
					$warning->{"location"}{"class"},
					$warning->{"location"}{"method"}, "true"
				);
				$bug_object->setClassName( $warning->{"location"}{"class"} );
			}
		}

		$bug_object->setBugMessage(
			sprintf( "%s (%s)", $warning->{"message"}, $warning->{"link"} ) );
		$bug_object->setBugCode( $warning->{"warning_type"} );
		$bug_object->setBugSeverity( $warning->{"confidence"} );
		$bug_object->setBugWarningCode( $warning->{"warning_code"} );
		$bug_object->setBugToolSpecificCode( $warning->{"code"} );
		$bug_object->setBugReportPath(
			Util::AdjustPath( $package_name, $cwd, "$input_dir/$input_file" ) );
		$xmlWriterObj->writeBugObject($bug_object);
	}
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
	Util::PrintWeaknessCountFile( $weakness_count_file,
		$xmlWriterObj->getBugId() - 1 );
}

