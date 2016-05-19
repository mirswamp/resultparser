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
my $count = 0;
my $temp_input_file;

my $twig = XML::Twig->new(
	twig_roots    => { 'errors' => 1 },
	twig_handlers => { 'error'  => \&parseViolations }
);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
    $temp_input_file = $input_file;
    $build_id        = $build_id_arr[$count];
    $count++;
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
    Util::PrintWeaknessCountFile( $weakness_count_file,
	    $xmlWriterObj->getBugId() - 1 );
}

sub parseViolations {
    my ( $tree, $elem ) = @_;

    my $bug_xpath = $elem->path();
    my $file      = "";
    my $lineno    = "";
    getCppCheckBugObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
    $elem->purge() if defined($elem);
    $tree->purge() if defined($tree);
}

sub getCppCheckBugObject() {
    my $violation           = shift;
    my $bugId               = shift;
    my $bug_xpath           = shift;
    my $bug_code            = $violation->att('id');
    my $bug_severity        = $violation->att('severity');
    my $bug_message         = $violation->att('msg');
    my $bug_message_verbose = $violation->att('verbose');
    my $bug_inconclusive    = $violation->att('inconclusive');
    my $bug_cwe             = $violation->att('cwe');

    my $bugObject  = new bugInstance($bugId);
    my $locationId = 0;

    foreach my $error_element ( $violation->children ) {
	my $tag    = $error_element->tag;
	my $file   = "";
	my $lineno = "";
	if ( $tag eq 'location' ) {
	    $file =
		    Util::AdjustPath( $package_name, $cwd,
		    $error_element->att('file') );
	    $lineno = $error_element->att('line');
	    $locationId++;
	    $bugObject->setBugLocation( $locationId, "",
		    Util::AdjustPath( $package_name, $cwd, $file ),
		    $lineno, $lineno, "0", "0", $bug_message, 'true', 'true' );
	}
    }

    $bugObject->setBugMessage($bug_message_verbose);
    $bugObject->setBugGroup($bug_severity);
    $bugObject->setBugCode($bug_code);
    $bugObject->setBugPath( $bug_xpath . "[" . $bugId . "]" );
    $bugObject->setBugBuildId($build_id);
    $bugObject->setBugInconclusive($bug_inconclusive)
	    if defined $bug_inconclusive;
    $bugObject->setCweId($bug_cwe) if defined $bug_cwe;
    $bugObject->setBugReportPath($temp_input_file);
    $xmlWriterObj->writeBugObject($bugObject);
    undef $bugObject if defined($bugObject);
}

