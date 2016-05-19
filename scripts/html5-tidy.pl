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
    while (<$fh>) {
	my $line = $_;
	chomp($line);

	#print "$line \n";
	#$line =~ /^line (\d+) column (\d+) - (\w+): (.*)/;
	my @fields     = split /:/, $line;
	my $fileName   = trim( $fields[0] );
	my $line_no    = trim( $fields[1] );
	my $col_no     = trim( $fields[2] );
	my $err_typ    = trim( $fields[3] );
	my $msg        = trim( $fields[4] );
	my $bug_object = new bugInstance( $xmlWriterObj->getBugId() );

	#FIXME: Decide on BugCode for tidy
	$bug_object->setBugCode($msg);
	$bug_object->setBugMessage($msg);
	$bug_object->setBugSeverity($err_typ);
	$bug_object->setBugBuildId($build_id);
	$bug_object->setBugReportPath($input_file );
	$bug_object->setBugLocation(
		1,  "", Util::AdjustPath($package_name, $cwd,$fileName), $line_no, $line_no, $col_no,
		"", "", 'true',    'true'
	);
	$xmlWriterObj->writeBugObject($bug_object);
    }
}
close($fh);

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
