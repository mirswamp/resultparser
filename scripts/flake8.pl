#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

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

my @parsed_summary = Util::ParseSummaryFile($summary_file);
my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser(@parsed_summary);
my @build_id_arr = Util::GetBuildIds(@parsed_summary);
undef @parsed_summary;

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;

my %severity_hash = ('C'=>'Convention','R'=>'Refactor','W'=>'Warning','E'=>'Error','F'=>'Fatal','I'=>'Information');

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	open( my $fh, "<", "$input_dir/$input_file" )
	  or die "Input file $input_dir/$input_file not found \n";
	while (<$fh>) {
		my ( $file, $line_num, $bug_code, $bug_msg, $bug_severity );
		my $line = $_;
		chomp($line);
		my @tokens = split( ':', $line );
		next if ( $#tokens != 2 );
		$file = Util::AdjustPath( $package_name, $cwd, $tokens[0] );
		$line_num = $tokens[1];
		$tokens[2] =~ /\[(.*?)\](.*)/;
		$bug_code = $1;
		$bug_msg  = $2;
		my $sever = substr( $bug_code, 0, 1 );
		$bug_severity = SeverityDet($sever);
		my $bugObj = new bugInstance($xmlWriterObj->getBugId());
		$bugObj->setBugLocation( 1, "", $file, $line_num, $line_num, 0, 0, "",
			'true', 'true' );
		$bugObj->setBugMessage($bug_msg);
		$bugObj->setBugCode($bug_code);
		$bugObj->setBugSeverity($bug_severity);
		$bugObj->setBugBuildId($build_id);
		$bugObj->setBugReportPath(Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ));
		$xmlWriterObj->writeBugObject($bugObj);
	}
	$fh->close;
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}

sub SeverityDet
{
    my $char = shift;
    if (exists $severity_hash{$char})
    {
        return($severity_hash{$char});
    }
    else
    {
        die "Unknown Severity $char";
    }
}
