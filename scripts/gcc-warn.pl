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

if( !$tool_name ) {
    $tool_name = Util::GetToolName($summary_file);
}

my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser($summary_file);

my $violationId = 0;
my $bugId       = 0;
my $locationId  = 0;
my $file_Id     = 0;

my $prev_line = "";
my $trace_start_line = 1;
my $methodId;
my $current_line_no;
my $fn_file;
my $function;
my $line;
my $message;
my $prev_msg;
my $prev_bug_group;
my $prev_fn;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my $temp_input_file;
my $bugObject;

foreach my $input_file (@input_file_arr) {
	$prev_msg="";
	$prev_bug_group="";
    $prev_fn="";
    $prev_line="";
    $trace_start_line=1;
    $locationId=0;
    $methodId=0;
    $temp_input_file = $input_file;
    
	my $input = new IO::File("<$input_dir/$input_file");
	print "\n<$input_dir/$input_file";
	my $fn_flag = -1;
    LINE:
	while ( my $line = <$input> ) {
		chomp($line);
		$current_line_no = $.;
		if ( $line eq $prev_line ) {
			next LINE;
		}
		else {
			$prev_line = $line;
		}
		my $valid = ValidateLine($line);
		if ( $valid eq "function" ) {
			my @tokens = Util::SplitString($line);
			$fn_file = $tokens[0];
			$function = $tokens[1];
			$function =~ /‘(.*)’/;
			$function = $1;
			$fn_flag = 1;
		} elsif ( $valid ne "invalid" ) {
			if($fn_flag==1){
				$fn_flag = -1;
			}else{
				$function = "";
				$fn_file = "";
			}
			ParseLine( $current_line_no, $line, $function, $fn_file );
		}
	}
	if(defined $bugObject){
	   RegisterBugpath($current_line_no);
	}
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub ParseLine {
	my ( $bug_report_line, $line, $function, $fn_file ) = @_;
	my @tokens = Util::SplitString($line);
	my $num_of_tokens = @tokens;
	my ( $file, $line_no, $col_no, $bug_group, $message );
	my $flag = 1;
	if ( $num_of_tokens eq 5 ) {
		$file      = Util::AdjustPath( $package_name, $cwd, $tokens[0] );
		$line_no   = $tokens[1];
		$col_no    = $tokens[2];
		$bug_group = $tokens[3];
		$message   = $tokens[4];
	}
	elsif ( $num_of_tokens eq 4 ) {
		$file      = Util::AdjustPath( $package_name, $cwd, $tokens[0] );
		$line_no   = $tokens[1];
		$col_no    = 0;
		$bug_group = $tokens[2];
		$message   = $tokens[3];
	}
	else {
		#bad line. hence skipping.
		$flag = 0;
	}

	if ( $flag ne 0 ) {
		$bug_group = Util::Trim($bug_group);
		$message   = Util::Trim($message);
		RegisterBug( $bug_report_line, $function, $fn_file, $file, $line_no,
			$col_no, $bug_group, $message );
	}
}

sub RegisterBugpath {
	my ($bug_report_line) = @_;
	my ( $bugLineStart, $bugLineEnd );
	if ( $bugId > 0 ) {    
		if ( $trace_start_line eq $bug_report_line - 1 ) {
			$bugLineStart = $trace_start_line;
			$bugLineEnd   = $trace_start_line;
		}
		else {
			$bugLineStart = $trace_start_line;
			$bugLineEnd   = $bug_report_line - 1;
		}
		$bugObject->setBugLine( $bugLineStart, $bugLineEnd );
		$trace_start_line = $bug_report_line;
	}
}

sub RegisterBug {
	my ( $bug_report_line, $function, $fn_file, $file, $line_no, $col_no, $bug_group, $message ) = @_;

	if ( $bug_group eq "note" and $bugId > 0 ) {
		if(! defined $bugObject){
		  return;
		}
		$bugObject->setBugLocation(++$locationId, "", $file, $line_no, $line_no, $col_no, 0, $message,"false", "true");
		$prev_msg       = $message;
		$prev_bug_group = $bug_group;
		$prev_fn        = $function;
		$xmlWriterObj->writeBugObject($bugObject);
		undef $bugObject;
		return;
	}
	if ($fn_file ne $file or $prev_msg ne $message or $prev_bug_group ne $bug_group or $prev_fn ne $function or $locationId > 99 ) {
		if(defined $bugObject){
			$xmlWriterObj->writeBugObject($bugObject);
			undef $bugObject;
		}
		$bugId++;
		$bugObject = new bugInstance($bugId);
		RegisterBugpath($bug_report_line);
		undef $bug_report_line;
		$methodId   = 0;
		$locationId = 0;
		$bugObject->setBugBuildId($build_id);
		$bugObject->setBugReportPath(Util::AdjustPath($package_name, $cwd, $temp_input_file));
		if ( $function ne '' ) {
			$bugObject->setBugMethod( ++$methodId, "", $function, "true" );
		}
		$bugObject->setBugGroup($bug_group);
		ParseMessage($message);
	}

	$bugObject->setBugLocation(++$locationId, "", $file, $line_no, $line_no, $col_no, 0, "", "true", "true");
	$prev_msg       = $message;
	$prev_bug_group = $bug_group;
	$prev_fn        = $function;
}

sub ParseMessage {
	my ($message) = @_;
	my $temp = $message;
	my $orig_msg  = $message;
	my $code      = $message;
	
	if ( defined($code) ) {
		$code =~ /(.*)\[(.*)\]$/;
		$message = $1;
		$code    = $2;
	}
	
	if(!defined $code or $code eq ""){
		$code = $temp;
		$code =~ s/(?: \d+)? of ‘.*?’//g;
		$code =~ s/^".*?" / /;
		$code =~ s/‘.*?’//g;
		$code =~ s/ ".*?"/ /g;
		$code =~ s/(?: to) ‘.*?’/ /g;
		$code =~ s/^(ignoring return value, declared with attribute).*/$1/;
		$code =~ s/^(#(?:warning|error)) .*/$1/;
		$code =~ s/cc1: warning: .*: No such file or directory/-Wmissing-include-dirs/;
	}
	

	if ( ( defined $message ) && ( $message ne '' ) ) {
		$bugObject->setBugMessage($message);
	}
	else { $bugObject->setBugMessage($orig_msg) }
	if ( ( defined $code ) && ( $code ne '' ) ) {
		$bugObject->setBugCode($code);
	}
}

sub ValidateLine {
	my ($line) = @_;
	if ( $line =~ m/^.*: *In .*function.*:$/i ) {
		return "function";
	}
	elsif ( $line =~ m/^.*: *In .*constructor.*:$/i ) {
		return "function";
	}
	elsif ( $line =~ m/.*: *warning *:.*/i ) {
		return "warning";
	}
	elsif ( $line =~ m/.*: *error *:.*/i ) {
		return "error";
	}
	elsif ( $line =~ m/.*: *note *:.*/i ) {
		return "note";
	}
	else {
		return "invalid";
	}
}

