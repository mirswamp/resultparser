#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ( $input_dir, $output_file, $tool_name, $summary_file, $weakness_count_file,
	$help, $version );
my $violationId = 0;
my $bugId       = 0;
my $file_Id     = 0;

GetOptions(
	"input_dir=s"           => \$input_dir,
	"output_file=s"         => \$output_file,
	"tool_name=s"           => \$tool_name,
	"summary_file=s"        => \$summary_file,
	"weakness_count_file=s" => \$$weakness_count_file,
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
my $file_path;

my $twig = XML::Twig->new(
	twig_roots         => { 'file'  => 1 },
	start_tag_handlers => { 'file'  => \&setFileName },
	twig_handlers      => { 'violation' => \&parseViolations }
);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

my $temp_input_file;

foreach my $input_file (@input_file_arr) {
    $temp_input_file = $input_file;
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub setFileName {
    my ( $tree, $element ) = @_;
    $file_path = $element->att('name');
    $element->purge() if defined($element);
    $file_Id++;

}

sub parseViolations {
    my ( $tree, $elem ) = @_;
    my $bug_xpath = $elem->path();

    my $bugObject =
	    getPHPMDBugObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
    $elem->purge() if defined($elem);
    $xmlWriterObj->writeBugObject($bugObject);
}


if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}


sub getPHPMDBugObject() {
    my $violation        = shift;
    my $adjustedFilePath = Util::AdjustPath( $package_name, $cwd, $file_path );
    my $bugId            = shift;
    my $bug_xpath        = shift;
    my $beginLine        = $violation->att('beginline');
    my $endLine          = $violation->att('endline');
    my $beginColumn =
      defined( $violation->att('column') ) ? $violation->att('column') : 0;
    my $endColumn   = $beginColumn;
    my $priority    = $violation->att('priority');
    my $message     = $violation->text;
    $message        =~ s/^\s+|\s+$//g;
    my $rule        = $violation->att('rule');
    my $ruleset     = $violation->att('ruleset');
    my $package     = $violation->att('package');
    my $class       = $violation->att('class');
    my $bugObject   = new bugInstance($bugId);
    ###################
    $bugObject->setBugLocation( 1, "", $adjustedFilePath, $beginLine, $endLine,
	    $beginColumn, 0, "", 'true', 'true' );
    $bugObject->setBugMessage($message);
    $bugObject->setBugSeverity($priority);
    $bugObject->setBugGroup($priority);
    $bugObject->setBugCode($ruleset);
    $bugObject->setBugPath(
	    $bug_xpath . "[" . $file_Id . "]" . "/error[" . $bugId . "]" );
    $bugObject->setBugBuildId($build_id);
    $bugObject->setBugReportPath(
	    $temp_input_file );
    return $bugObject;
}

