#!/usr/bin/perl -w

use strict;
use warnings;
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

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	my $json_data = "";
	$build_id = $build_id_arr[$count];
	$count++;
	{
		open FILE, "$input_dir/$input_file"
		  or die "open $input_dir/$input_file : $!";
		local $/;
		$json_data = <FILE>;
		close FILE or die "close $input_dir/$input_file : $!";
	}
	my $json_obj = JSON->new->utf8->decode($json_data);

	foreach my $warning ( @{ $json_obj->{"vulnerabilities"} } ) {
		$bugId = $xmlWriterObj->getBugId();
		my $bug_object = new bugInstance($bugId);
		my $name       = $warning->{"name"};
		my $cvss_score = $warning->{"cvss_score"};
		if ( defined $cvss_score && $cvss_score ne "null" ) {
			$bug_object->setCWEInfo($cvss_score);
		}
		$bug_object->setBugCode($name);
		$bug_object->setBugMessage( $warning->{"message"} );
		$bug_object->setBugSeverity( $warning->{"severity"} );
		$bug_object->setBugRank( $warning->{"priority"} );
		$bug_object->setBugSuggestion( $warning->{"remediation"} );
		$bug_object->setBugReportPath(
			sprintf( "/vulnerabilities/[%d]", $bugId ) );
		my $cve_link = $warning->{"cve_link"};

		if ( defined $cve_link && $cve_link ne "null" ) {
			$bug_object->setURLText($cve_link);
		}
		elsif ( $name =~ m/^\s*CVE.*$/i ) {
			$bug_object->setURLText(
				"https://cve.mitre.org/cgi-bin/cvename.cgi?name=" . $name );
		}

		#TODO : Add links to OSDVB and OWASP codes
		$xmlWriterObj->writeBugObject($bug_object);
	}
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
	Util::PrintWeaknessCountFile( $weakness_count_file,
		$xmlWriterObj->getBugId() - 1 );
}

