#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

my ( $input_dir, $output_file, $tool_name, $summary_file );

GetOptions(
	"input_dir=s"    => \$input_dir,
	"output_file=s"  => \$output_file,
	"tool_name=s"    => \$tool_name,
	"summary_file=s" => \$summary_file
) or die("Error");

if ( !$tool_name ) {
	$tool_name = Util::GetToolName($summary_file);
}

my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser($summary_file);

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	my $start_bug = 0;
	open( my $fh, "<", "$input_dir/$input_file" )
		or die "unable to open the input file $input_file";
	while (<$fh>) {
		my $line = $_;
		chomp($line);
		if ( $line =~ /Info/ ) {
			last;
		}
		if ( $line =~ /^line/ ) {
			$line =~ /^line (\d+) column (\d+) - (\w+): (.*)/;
			my $line_no = $1;
			my $col_no  = $2;
			my $err_typ = $3;
			my $msg     = $4;
			my $bug_object =
			new bugInstance( $xmlWriterObj->getBugId() );
			$bug_object->setBugLocation(
				1,        "", $filepath, $line_no,
				$line_no, "", $col_no,        "",
				'true',   'true'
			);
			#FIXME: Decide on BugCode for tidy
			$bug_object->setBugCode($msg);
			$bug_object->setBugMessage($msg);
			$bug_object->setBugSeverity($err_typ);
			$bug_object->setBugBuildId($build_id);
			$bug_object->setBugReportPath(
				Util::AdjustPath(
					$package_name, $cwd, "$input_dir/$input"
				)
			);
			$xmlWriterObj->writeBugObject($bug_object);
		}
	}
}
$fh->close();

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
