#!/usr/bin/perl -w

use strict;
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
my $count = 0;

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;
my ( $bugCode, $bugmsg, $line_no, $filepath );

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

if ( $tool_version ne "8ba3536" ) {
	my $begin_line;
	my $end_line;
	my $json_data = "";
	foreach my $input_file (@input_file_arr) {
		{
			$build_id = $build_id_arr[$count];
			$count++;
			open FILE, "$input_dir/$input_file"
			  or die "open $input_dir/$input_file : $!";
			local $/;
			$json_data = <FILE>;
			close FILE or die "close $input_file : $!";
		}
		my $json_object = JSON->new->utf8->decode($json_data);

		foreach my $warning ( @{ $json_object->{"results"} } ) {
			my $bug_object =
			  GetBanditBugObjectFromJson( $warning, $xmlWriterObj->getBugId() );
			$xmlWriterObj->writeBugObject($bug_object);
		}
	}
}
else {
	foreach my $input_file (@input_file_arr) {
		$build_id = $build_id_arr[$count];
		$count++;
		my $start_bug = 0;
		open( my $fh, "<", "$input_dir/$input_file" )
		  or die "unable to open the input file $input_file";
		while (<$fh>) {
			my $line = $_;
			chomp($line);
			if ( $line = ~/Test results:/ ) {
				$start_bug = 1;
				next;
			}
			next if ( $start_bug == 0 );
			my $first_line_seen = 0;
			if ( $line =~ /^\>\>/ ) {
				if ( $first_line_seen > 0 ) {
					my $bug_object =
					  new bugInstance( $xmlWriterObj->getBugId() );
					$bug_object->setBugLocation(
						1,        "", $filepath, $line_no,
						$line_no, "", "",        "",
						'true',   'true'
					);
					$bug_object->setBugCode($bugCode);
					$bug_object->setBugMessage($bugmsg);
					$bug_object->setBugBuildId($build_id);
					$bug_object->setBugReportPath(
						Util::AdjustPath(
							$package_name, $cwd, "$input_dir/$input"
						)
					);
					$xmlWriterObj->writeBugObject($bug_object);
					undef $bugCode;
					undef $bugmsg;
					undef $filepath;
					undef $line_no;
				}
				$first_line_seen = 1;
				$line =~ s/^\>\>//;
				$bugCode = $line;
				$bugmsg  = $line;
			}
			else {
				my @tokens = split( "::", $line );
				if ( $#tokens == 1 ) {
					$tokens[0] =~ s/^ - //;
					$filepath =
					  Util::AdjustPath( $package_name, $cwd, $tokens[0] );
					$line_no = $tokens[1];
				}
			}
		}
		$fh->close();
	}

}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
	Util::PrintWeaknessCountFile( $weakness_count_file,
		$xmlWriterObj->getBugId() - 1 );
}

sub GetBanditBugObjectFromJson() {
	my $warning = shift;
	my $bug_id  = shift;
	my $bug_object = new bugInstance($bug_id);
	$bug_object->setBugCode( $warning->{"test_name"} );
	$bug_object->setBugMessage( $warning->{"issue_text"} );
	$bug_object->setBugSeverity( $warning->{"issue_severity"} );
	$bug_object->setBugBuildId($build_id);
	$bug_object->setBugReportPath(
		Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ) );
	my $begin_line = $warning->{"line_number"};
	my $end_line;

	foreach my $number ( @{ $warning->{"line_range"} } ) {
		$end_line = $number;
	}
	my $filename = Util::AdjustPath( $package_name, $cwd, $warning->{"filename"} );
	$bug_object->setBugLocation(
		1,         "",  $filename, $begin_line,
		$end_line, "0", "0",       "",
		'true',    'true'
	);
	return $bug_object;
}

