#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
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

my @parsed_summary = Util::ParseSummaryFile($summary_file);
my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
			  = Util::InitializeParser(@parsed_summary);
my @build_id_arr = Util::GetBuildIds(@parsed_summary);
undef @parsed_summary;

my $twig = XML::Twig->new(
	twig_roots    => { 'module'   => 1 },
	twig_handlers => { 'function' => \&parseMetric }
);

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
    $build_id = $build_id_arr[$count];
    $count++;
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub parseMetric {
    my ( $tree, $elem ) = @_;

    my $bug_xpath = $elem->path();

    my $bugObject =
	    GetXMLObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
    $elem->purge() if defined($elem);

    $xmlWriterObj->writeBugObject($bugObject);
}

sub GetXMLObject() {
    my $elem             = shift;
    my $adjustedFilePath = Util::AdjustPath( $package_name, $cwd, $file_path );
    my $bugId            = shift;
    my $bug_xpath        = shift;

    # Ignoring Halstead Metrics
    my $funcName = $elem->att('name');
    my $line     = $elem->first_child('line')->text;
    my $ccn      = $elem->first_child('cyclomatic')->text;
    my $cd       = $elem->first_child('cyclomatic-density')->text;
    my $params   = $elem->first_child('parameters')->text;
    my $sloc     = $elem->first_child('sloc');
    my $psloc    = $sloc->first_child('physical')->text;
    my $lsloc    = $sloc->first_child('logical')->text;

    # TODO: Populate Metric Object

    $bugObject->setBugMessage($message);
    $bugObject->setBugCode($source_rule);
    return $bugObject;
}

