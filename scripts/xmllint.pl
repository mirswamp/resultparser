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
		or die "Unable to open the input file $input_file";
	while (<$fh>) {
		my $line = $_;
		chomp($line);
		if ( ($line =~ /^$/) or ($line eq '^') ) {
			next;
		}
		my @fields = split /:/, $line, 4;
		if (scalar @fields eq 4) {
			my $bug_object =
			new bugInstance( $xmlWriterObj->getBugId() );
			$bug_object->setBugLocation(
				1,        "", trim($fields[0]), trim($fields[1]),
				trim($fields[1]), "", "",        "",
				'true',   'true'
			);
			#FIXME: Decide on BugCode for xmllint
			$bug_object->setBugCode(trim($fields[3]));
			$bug_object->setBugMessage(trim($fields[3]));
			$bug_object->setBugSeverity(trim($fields[2]));
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

sub trim {
	(my $s = $_[0]) =~ s/^\s+|\s+$//g;
	return $s;
}
