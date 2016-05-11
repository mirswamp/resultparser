#!/usr/bin/perl
package Parser;

use strict;
use Getopt::Long;
use Util;
use xmlWriterObject;

my @input_file_arr;
my @build_id_arr;
my $xmlWriterObj;

sub new {
	my $class = shift;
	my $self;
	bless $self, $class;
	return $self;
}

sub InitializeParser {
	my $self = shift;
	GetOptions(
		"input_dir=s"           => \$self->{_input_dir},
		"output_file=s"         => \$self->{_output_file},
		"tool_name=s"           => \$self->{_tool_name},
		"summary_file=s"        => \$self->{_summary_file},
		"weakness_count_file=s" => \$self->{_weakness_count_file},
		"help"                  => \$self->{_help},
		"version"               => \$self->{_version}
	) or die("Error");

	Util::Usage()   if defined( $self->{_help} );
	Util::Version() if defined( $self->{_version} );

	if ( !defined $self->{_summary_file} ) {
		die "No summary file specified. Exiting.";
	}
	if ( !defined $self->{_tool_name} ) {
		$self->{_tool_name} = Util::GetToolName( $self->{_summary_file} );
	}

	my @parsed_summary = Util::ParseSummaryFile( $self->{_summary_file} );

	(
		$self->{_uuid},         $self->{_package_name},
		$self->{_build_id},     $self->{_input},
		$self->{_cwd},          $self->{_replace_dir},
		$self->{_tool_version}, @input_file_arr
	) = Util::InitializeParser(@parsed_summary);

	@build_id_arr = Util::GetBuildIds(@parsed_summary);
	undef @parsed_summary;
	$xmlWriterObj = new xmlWriterObject( $self->{_output_file} );
	$xmlWriterObj->addStartTag( $self->{_tool_name}, $self->{_tool_version},
		$self->{_uuid} );
}

sub GetInputFileArr {
	return @input_file_arr;
}

sub GetBuildID {
	my $index = shift;
	return $build_id_arr[$index];
}

sub GetInputDir {
	my $self = shift;
	return $self->{_input_dir};
}

sub GetPackageName {
	my $self = shift;
	return $self->{_package_name};
}

sub GetCWD {
	my $self = shift;
	return $self->{_cwd};
}

sub WriteBugObject {
	my ( $self, $bugObject ) = @_;
	$xmlWriterObj->writeBugObject($bugObject);
}

sub EndXML {
	my $self = shift;
	$xmlWriterObj->writeSummary();
	$xmlWriterObj->addEndTag();
	if ( defined $self->{_weakness_count_file} ) {
		Util::PrintWeaknessCountFile( $self->{_weakness_count_file},
			$xmlWriterObj->getBugId() - 1 );
	}
}
1
