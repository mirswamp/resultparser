#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ( $input_dir, $output_file, $tool_name, $summary_file, $weakness_count_file,
	$help, $version );

GetOptions(
	"input_dir=s"		=> \$input_dir,
	"output_file=s"		=> \$output_file,
	"tool_name=s"		=> \$tool_name,
	"summary_file=s"	=> \$summary_file,
	"weakness_count_file=s" => \$weakness_count_file,
	"help"			=> \$help,
	"version"		=> \$version
) or die("Error");

Util::Usage()	if defined($help);
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

my $count = 0;

my $twig = XML::Twig->new(
	twig_handlers => {
		'warning'	     => \&GetFileDetails,
		'warning/categories' => \&GetCWEDetails,
		'warning/listing'    => \&GetListingDetails
	}
    );

#Initialize the counter values
my $file_path = "";
my $event_num;
my ( $line, $bug_group, $file_name, $severity, $method, $bug_message, $file );
my @bugCode_cweId;    # first element is bug code and other elements are cweids
my $temp_bug_object;
my %buglocation_hash;

opendir( DIR, $input_dir );
my @filelist = grep { -f "$input_dir/$_" && $_ =~ m/\.xml$/ } readdir(DIR);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@filelist) {
    $temp_input_file = $input_file;
    $build_id = $build_id_arr[$count];
    $count++;
    $event_num	 = 1;
    $bug_message = "";
    undef($method);
    undef(@bugCode_cweId);
    undef($severity);
    undef($file_name);
    undef($bug_group);
    undef($line);
    $twig->parsefile("$input_dir/$input_file");
    my $bug_object = new bugInstance( $xmlWriterObj->getBugId() );
    $temp_bug_object = $bug_object;
    $bug_object->setBugMessage($bug_message);
    $bug_object->setBugSeverity($severity);
    $bug_object->setBugGroup($bug_group);
    $bug_object->setBugCode( shift(@bugCode_cweId) );
    $bug_object->setBugReportPath($temp_input_file);
    $bug_object->setBugBuildId( $build_id, );
    $bug_object->setBugMethod( 1, "", $method, "true" );
    $bug_object->setCWEArray(@bugCode_cweId);
    my @events = sort { $a <=> $b } ( keys %buglocation_hash );

    foreach my $elem ( sort { $a <= $b } @events ) {
	my $primary = ( $elem eq $events[$#events] ) ? "true" : "false";
	my @tokens = split( ":", $buglocation_hash{$elem} );
	$bug_object->setBugLocation(
	    $elem,	"",  $tokens[0], $tokens[1],
	    $tokens[1], "0", "0",	 $tokens[2],
	    $primary,	"true"
	);
    }
    $xmlWriterObj->writeBugObject($bug_object);
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub GetFileDetails {
    my ( $tree, $elem ) = @_;
    $line      = $elem->att('line_number');
    $bug_group = $elem->att('warningclass');
    $severity  = $elem->att('priority');
    $file_name =
	    Util::AdjustPath( $package_name, $cwd, $elem->att('filename') );
    $method = $elem->att('procedure');

}

sub GetCWEDetails {
    my ( $tree, $elem ) = @_;
    foreach my $cwe ( $elem->children('category') ) {
	push( @bugCode_cweId, $cwe->field );
    }
}

sub GetListingDetails {
    my ( $tree, $elem ) = @_;
    foreach my $procedure ( $elem->children ) {
	ProcedureDetails( $procedure, "" );
    }

}

sub ProcedureDetails {
    my $procedure      = shift;
    my $file_name      = shift;
    my $procedure_name = $procedure->att('name');
    if ( defined( $procedure->first_child('file') ) ) {
	$file_name =
		Util::AdjustPath( $package_name, $cwd,
			$procedure->first_child('file')->att('name') );
    }
    foreach my $line ( $procedure->children('line') ) {
	LineDetails( $line, $procedure_name, $file_name );
    }
}

sub LineDetails {
    my $line	       = shift;
    my $procedure_name = shift;
    my $file_name      = shift;
    my $line_num       = $line->att('number');
    my $message;

    foreach my $inner ( $line->children ) {
	if ( $inner->gi eq 'msg' ) {
	    msg_format_star($inner);
	    msg_format($inner);
	    my $message = msg_details($inner);
	    $message =~ s/^\n*//;
	    $event_num = $inner->att("msg_id");
	    $buglocation_hash{$event_num} =
		    $file_name . ":" . $line_num . ":" . $message;
	    $bug_message =
		    $bug_message
		    . " Event $event_num at $file_name:$line_num: "
		    . $message . "\n\n";
	}
	else {
	    InnerDetails( $inner, $file_name );
	}
    }
}

sub InnerDetails {
    my $misc_details = shift;
    my $file_name    = shift;
    if ( $misc_details->gi eq 'procedure' ) {
	ProcedureDetails( $misc_details, $file_name );
    }
    else {
	foreach my $inner ( $misc_details->children ) {
	    InnerDetails( $inner, $file_name );
	}
    }
}

sub msg_format_star {
    my $msg = shift;
    my @list;

    @list = $msg->descendants;
    foreach my $elem (@list) {
	if ( $elem->gi eq 'li' ) {
	    $elem->prefix("* ");
	}
    }
}

sub msg_format {
    my $msg = shift;
    my @list;
    foreach my $msg_child ( $msg->children ) {
	if ( $msg_child->gi eq 'ul' ) {
	    @list = $msg_child->descendants;
	    foreach my $elem (@list) {
		if ( $elem->gi eq "li" ) {
		    $elem->prefix("   ");
		}
	    }
	}
	msg_format($msg_child);
    }

    return;
}

sub msg_details {
    my $msg	= shift;
    my $message = $msg->sprint();
    $message =~ s/\<li\>/\n/g;
    $message =~ s/\<link msg="m(.*?)"\>(.*?)\<\/link\>/ [event $1, $2]/g;
    $message =~ s/\<paragraph\>/\n/g;
    $message =~ s/\<link msg="m(.*?)"\>/[event $1] /g;
    $message =~ s/\<.*?\>//g;
    $message =~ s/,\s*]/]/g;
    $message =~ s/&lt;/\</g;
    $message =~ s/&amp;/&/g;
    $message =~ s/&gt;/>/g;
    $message =~ s/&quot;/"/g;
    $message =~ s/&apos;/'/g;
    return $message;
}
