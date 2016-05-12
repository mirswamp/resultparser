#!/usr/bin/perl -w

#use strict;
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
my $temp_input_file;

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

my $prev_msg;
my $prev_fn;
my $prev_line;
my $trace_start_line;
my $suggested_message;
my $current_line_no;
my $not_mssg;
my $first_report
  ; #this variable is defined so that the first bug report of a file doesnot try to change the bug instance of its previous bug report.
my $input_text;

foreach my $input_file (@input_file_arr) {
	$temp_input_file = $input_file;
	$build_id = $build_id_arr[$count];
	$count++;
	$not_message       = 0;
	$prev_line         = "";
	$first_report      = 1;
	$suggested_message = "";
	$current_line_no   = 0;
	$prev_msg          = "";
	$prev_fn           = "";
	$trace_start_line  = 1;
	$input_text        = new IO::File("<$input_dir/$input_file");

	my $temp_bug_object;
	$input_text = defined($input_text) ? $input_text : "";
	my $temp;

  LINE:
	while ( my $line = <$input_text> ) {
		chomp($line);
		$current_line_no = $.;
		my @tokens = split( ':', $line );
		if ( ( $#tokens != 3 && $not_message == 1 ) |
			( ( $#tokens == 3 ) && !( $tokens[3] =~ /^\s*\[.*\]/ ) ) )
		{
			$not_message = 1;
			next;
		}
		else {
			$not_message = 0;
		}

		if ( $line eq $prev_line ) {
			next LINE;
		}
		else {
			$prev_line = $line;
		}
		ParseLine( $current_line_no, $line, $input_file );
		$temp = $line;
	}
	RegisterBugPath( $current_line_no, $input_file );
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
	Util::PrintWeaknessCountFile( $weakness_count_file,
		$xmlWriterObj->getBugId() - 1 );
}

sub ParseLine {
	my ( $bug_report_line, $line, $input_file ) = @_;
	my @tokens        = SplitString($line);
	my $num_of_tokens = @tokens;
	my ( $file, $line_no, $message, $severity, $code, $resolution_msg );
	my $flag = 1;
	if ( $num_of_tokens eq 4 && !( $line =~ m/^\s*Did you mean.*$/i ) ) {
		$file     = Util::AdjustPath( $package_name, $cwd, $tokens[0] );
		$line_no  = $tokens[1];
		$severity = Util::Trim( $tokens[2] );
		$message  = $tokens[3];
		$code     = $message;
		$code =~ /^\s*\[(.*)\].*$/;
		$code = $1;
	}
	elsif ( $line =~ m/^\s*Did you mean.*$/i ) {
		$resolution_msg = Util::Trim($line);
		SetResolutionMsg($resolution_msg);
		$flag = 0;
	}
	elsif ( $line =~ m/^\s*required:.*/i ) {
		$suggested_message = Util::Trim($line);
		$flag              = 0;
	}
	elsif ( $line =~ m/^\s*found:.*/i ) {
		$suggested_message = $suggested_message . " , " . Util::Trim($line);
		SetResolutionMsg($suggested_message);
		$flag              = 0;
		$suggested_message = "";
	}
	elsif ( $line =~ m/^\s*see http:.*/i ) {
		my $url_text = Util::Trim($line);
		SetURLText($url_text);
		$flag = 0;
	}
	elsif ( $line =~ m/^\s*\^.*/i ) {
		my $column = length $line;
		$column = $column - 1;
		$flag   = 0;
		SetColumnNumber($column);
	}
	else {
		$flag = 0;
	}
	if ( $flag ne 0 ) {
		$message = Util::Trim($message);

		$temp_bug_object =
		  CreateBugObject( $bug_report_line, $file, $line_no, $message,
			$severity, $code, $input_file );
		$first_report = 0;
	}
}

sub RegisterBugPath {
	my ($bug_report_line) = shift;
	my $input_file = shift;
	if ( $first_report == 1 ) {
		return;
	}
	if ( defined $temp_bug_object ) {  #Store the information for prev bug trace
		my ( $bugLineStart, $bugLineEnd );
		if ( $trace_start_line eq $bug_report_line - 1 ) {
			$bugLineStart = $trace_start_line;
			$bugLineEnd   = $trace_start_line;
		}
		else {
			$bugLineStart = $trace_start_line;
			$bugLineEnd   = $bug_report_line - 1;
		}
		$temp_bug_object->setBugLine( $bugLineStart, $bugLineEnd );
		$temp_bug_object->setBugBuildId($build_id);
		$temp_bug_object->setBugReportPath($temp_input_file);
		$trace_start_line = $bug_report_line;
	}

	if ( defined $temp_bug_object ) {
		$xmlWriterObj->writeBugObject($temp_bug_object);
	}
}

sub CreateBugObject {
	my ( $bug_report_line, $file, $line_no, $message, $severity, $code,
		$input_file )
	  = @_;

	#Store the information for prev bug trace
	RegisterBugPath( $bug_report_line, $input_file );

	#New Bug Instance
	my $methodId   = 0;
	my $locationId = 0;
	my $bug_object = new bugInstance( $xmlWriterObj->getBugId() );
	$bug_object->setBugMessage($message);
	if ( defined($code) and $code ne '' ) { $bug_object->setBugCode($code); }
	if ( defined($severity) and $severity ne '' ) {
		$bug_object->setBugSeverity($severity);
	}

	$bug_object->setBugLocation( ++$locationId, "", $file, $line_no, $line_no,
		0, 0, "", "true", "true" );

	undef $temp_bug_object;
	return $bug_object;
}

sub SetResolutionMsg {
	my ($res_msg) = @_;
	if ( defined $temp_bug_object ) {
		$temp_bug_object->setBugSuggestion($res_msg);
	}
}

sub SetURLText {
	my ($url_txt) = @_;
	if ( defined $temp_bug_object ) {
		$temp_bug_object->setURLText($url_txt);
	}
}

sub SetColumnNumber {
	my ($column) = @_;
	if ( defined $temp_bug_object ) {
		$temp_bug_object->setBugColumn( $column, $column, 1 );
	}
}

sub SplitString {
	my ($str) = @_;
	$str =~ s/::+/~#~/g;
	my @tokens = split( ':', $str, 4 );
	my @ret;
	foreach $a (@tokens) {

		#                print $a,"\n";
		$a =~ s/~#~/::/g;
		push( @ret, $a );
	}
	return (@ret);
}

