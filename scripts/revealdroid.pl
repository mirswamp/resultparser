#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
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

my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser($summary_file);
  
my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	my $build_stdout_check_flag = 1;
	if ( !-e "$input_dir/$input_file" ) {
		print "no inputfile";
		$build_stdout_check_flag = 0;
	}
	die "ERROR!! Revealdroid assessment run did not complete. build_stdout.out file is missing. \n" if ( $build_stdout_check_flag eq 0 );
	
	my $file = "build_stdout.out";
	open my $fh, "<", "$input_dir/$input_file" or die "Could not open file $input_dir/$input_file";
	my @lines = Readline($fh);
	close $fh;
	chomp @lines;
	my $confidence = "";
	my $bugType    = "";
	my $flag       = 0;
	foreach (@lines) {

		if ( $_ =~ /^[Reputation]/ ) {
			my @rep_conf_split = split /:/, $_;
			$rep_conf_split[1] =~ s/^\s+//;
			$rep_conf_split[1] =~ s/\s+$//;
			if ( $flag == 1 ) {
				$bugType = $rep_conf_split[1];
				last;
			}
			else {
				$confidence = $rep_conf_split[1];
				$flag       = 1;
			}
		}
	}
	if ( ( $bugType eq "Benign" ) and ( $confidence == 1 ) ) {
		return 1;
	}

	#Create Bug Object#
	my $file_data;
	my $bug_object = new bugInstance($xmlWriterObj->getBugId());
	{
		open FILE, "$input_dir/$input_file" or die "open $input_dir/$input_file: $!";
		local $/;
		$file_data = <FILE>;
		close FILE or die "close $input_dir/$input_file: $!";
	}
	$bug_object->setBugMessage($file_data);
	foreach (@lines) {
		if ( $_ =~ /^[Reputation]/ ) {
			my @reputation_split = split /:/, $_;
			$reputation_split[1] =~ s/^\s+//;
			$reputation_split[1] =~ s/\s+$//;
			$bug_object->setBugGroup( $reputation_split[1] );
		}
		elsif ( $_ =~ /^[Family]/ ) {
			my @family_split = split /:/, $_;
			$family_split[1] =~ s/^\s+//;
			$family_split[1] =~ s/\s+$//;
			$bug_object->setBugCode( $family_split[1] );
		}
	}
	$xmlWriterObj->writeBugObject($bug_object);
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

