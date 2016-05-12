#!/usr/bin/perl

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

sub trim {
	( my $s = $_[0] ) =~ s/^\s+|\s+$//g;
	return $s;
}

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

my $fh;
foreach my $input_file (@input_file_arr) {
	my $start_bug = 0;
	$build_id = $build_id_arr[$count];
	$count++;
	open( $fh, "<", "$input_dir/$input_file" )
	  or die "unable to open the input file $input_file";

	while ( my $line = <$fh> ) {
		chomp($line);
		if ( $line =~ /.* line (\d+), column (\d+)./ ) {
			my $l  = $1;
			my $c  = $2;
			my $l2 = <$fh>;
			if ( $l2 =~ /^  / ) {
				$l2 =~ /.* (\w+)::(\w+) \(Severity: (\d+)\)/;
				my $class = $1;
				my $rule  = $2;
				my $sev   = $3;
				my $msg   = '';
				while ( my $l3 = <$fh> ) {
					if ( $l3 =~ /^    / ) {
						$msg = $msg . ' ' . trim($l3);
					}
					elsif ( $l3 =~ /^(\w)/ ) {
						last;
					}
					elsif ( $3 =~ /^$/ ) {
						$msg = $msg . "\n\n";
					}
					else {

						#Nothing to handle!
					}
				}
			}
		}
		my $bug_object = new bugInstance( $xmlWriterObj->getBugId() );

		#FIXME: Decide on BugCode for perlcritic
		#$bug_object->setBugCode($msg);
		$bug_object->setBugMessage($msg);
		$bug_object->setBugSeverity($sev);
		$bug_object->setBugBuildId($build_id);
		$bug_object->setBugReportPath(
			Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ) );
		$bug_object->setBugLocation( 1, "", $fileName, $l, $l, $c, "", "",
			'true', 'true' );
		$xmlWriterObj->writeBugObject($bug_object);
	}
}
close($fh);

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
	Util::PrintWeaknessCountFile( $weakness_count_file,
		$xmlWriterObj->getBugId() - 1 );
}
