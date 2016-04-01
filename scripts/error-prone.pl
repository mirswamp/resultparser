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

my $prev_msg;
my $prev_fn;
my $prev_line;
my $trace_start_line;
my $suggested_message;
my $current_line_no;
my $not_mssg;
my $first_report
  ; #this variable is defined so that the first bug report of a file doesnot try to change the bug instance of its previous bug report.

foreach my $input_file (@input_file_arr) {
	$not_message       = 0;
	$prev_line         = "";
	$first_report      = 1;
	$suggested_message = "";
	$current_line_no   = 0;
	$prev_msg          = "";
	$prev_fn           = "";
	$trace_start_line  = 1;
	$input_text        = new IO::File("<$input_file");
	
	my $temp_bug_instance;

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
		ParseLine( $current_line_no, $line );
	}

	RegisterBugPath($current_line_no);
}

sub ParseLine {
	my ( $bug_report_line, $line ) = @_;
	my @tokens        = Util::SplitString($line);
	my $num_of_tokens = @tokens;
	my ( $file, $line_no, $message, $severity, $code, $resolution_msg );
	my $flag = 1;
	if ( $num_of_tokens eq 4 ) {
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
	else {
		$flag = 0;
	}
	if ( $flag ne 0 ) {
		$message = Util::Trim($message);
		$temp_bug_object = CreateBugObject( $bug_report_line, $file, $line_no, $message, $severity,
			$code );
		$first_report = 0;
	}
}

sub RegisterBugpath {
	my ($bug_report_line) = @_;
	if ($first_report) {
		return;
	}
	if ( $xmlWriterObj->getBugId() > 0 )
	{ #Store the information for prev bug trace
		my ( $bugLineStart, $bugLineEnd );
		if ( $trace_start_line eq $bug_report_line - 1 ) {
			$bugLineStart = $trace_start_line;
			$bugLineEnd   = $trace_start_line;
		}
		else {
			$bugLineStart = $trace_start_line;
			$bugLineEnd   = $bug_report_line - 1;
		}
		$temp_bug_object
		  ->setBugLine( $bugLineStart, $bugLineEnd );
		$temp_bug_object->setBugBuildId($build_id);
		$temp_bug_object->setBugReportPath($input_file);
		$trace_start_line = $bug_report_line;
	}

}

sub CreateBugObject {
    my($bug_report_line,$file,$line_no,$message,$severity,$code) = @_;
        #Store the information for prev bug trace
        RegisterBugpath($bug_report_line);
                
        #New Bug Instance
        $methodId=0;
        $locationId=0;
        my $bug_object = new bugInstance($xmlWriterObj->getBugId());
        $bug_object->setBugMessage($message);
        if (defined ($code) and $code ne '') {  $bug_object->setBugCode($code);}
        if (defined ($severity) and $severity ne '') {  $bug_object->setBugSeverity($severity);}
        
        $bug_object->setBugLocation(++$locationId,"",$file,$line_no,$line_no,0,0,"","true","true");
        
        return $bug_object;
}

sub SetResolutionMsg {
    my($res_msg)=@_;
    if($xmlWriterObj->getBugId() > 0) {
        temp_bug_object->setBugSuggestion($res_msg);
    }
}

