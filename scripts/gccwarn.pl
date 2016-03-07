#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use util;

my (
	$input_file,   $output_file, $tool_name, $tool_version, $uuid,
	$package_name, $build_id,    $cwd,       $replace_dir,  $file_path
);
my $violationId = 0;
my $bugId       = 0;
my $locationId  = 0;
my $file_Id     = 0;

my $prev_line = "";
my $trace_start_line = 1;
my $current_line_no;
my $fn_file;
my $function;
my $line;
my $message;


GetOptions(
	"input_file=s"     => \$input_file,
	"output_file=s"    => \$output_file,
	"tool_name=s"      => \$tool_name,
	"tool_version=s"   => \$tool_version,
	"package_name=s"   => \$package_name,
	"uuid=s"           => \$uuid,
	"build_id=s"       => \$build_id,
	"cwd=s"            => \$cwd,
	"replace_dir=s"    => \$replace_dir,
	"input_file_arr=s" => \@input_file_arr
) or die("Error");

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my $bugObject;

foreach my $input_file (@input_file_arr) {
	$prev_msg="";
	$prev_bug_group="";
    $prev_fn="";
    $prev_line="";
    $trace_start_line=1;
    $locationId=0;
    $methodId=0;
    
   # my $filehandler = IO::File->new();
    #$filehandler->open($input_file,'<:encoding(UTF-8)'); 
	my $input = new IO::File("<$input_file");
	#open(my $input, "<:encoding(UTF-8)", "$input_file")
    #|| die "can't open UTF-8 encoded filename: $!";
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
		my $valid = &validate_line($line);
		if ( $valid eq "function" ) {
			my @tokens = util::SplitString($line);
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
			&parse_line( $current_line_no, $line, $function, $fn_file );
		}
	}
	if(defined $bugObject){
	   &register_bugpath($current_line_no);
	}
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub parse_line {
	my ( $bug_report_line, $line, $function, $fn_file ) = @_;
	my @tokens = util::SplitString($line);
	my $num_of_tokens = @tokens;
	my ( $file, $line_no, $col_no, $bug_group, $message );
	my $flag = 1;
	if ( $num_of_tokens eq 5 ) {
		$file      = util::AdjustPath( $package_name, $cwd, $tokens[0] );
		$line_no   = $tokens[1];
		$col_no    = $tokens[2];
		$bug_group = $tokens[3];
		$message   = $tokens[4];
	}
	elsif ( $num_of_tokens eq 4 ) {
		$file      = util::AdjustPath( $package_name, $cwd, $tokens[0] );
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
		$bug_group = util::trim($bug_group);
		$message   = util::trim($message);
		&register_bug( $bug_report_line, $function, $fn_file, $file, $line_no,
			$col_no, $bug_group, $message );
	}
}

sub register_bugpath {
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

sub register_bug {
	my ( $bug_report_line, $function, $fn_file, $file, $line_no, $col_no, $bug_group, $message ) = @_;

	if ( $bug_group eq "note" and $bugId > 0 ) {
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
		&register_bugpath($bug_report_line);
		$methodId   = 0;
		$locationId = 0;
		$bugObject->setBugBuildId($build_id);
		$bugObject->setBugReportPath(util::AdjustPath($package_name, $cwd, $input_file));
		if ( $function ne '' ) {
			$bugObject->setBugMethod( ++$methodId, "", $function, "true" );
		}
		$bugObject->setBugGroup($bug_group);
		&parse_message($message);
	}

	$bugObject->setBugLocation(++$locationId, "", $file, $line_no, $line_no, $col_no, 0, "", "true", "true");
	$prev_msg       = $message;
	$prev_bug_group = $bug_group;
	$prev_fn        = $function;
}

sub parse_message {
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

sub validate_line {
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

