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
	twig_roots    => { 'package' => 1 },
	twig_handlers => { 'class'   => \&parseMetric }
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
    my $elem      = shift;
    my $className = $elem->att('name');
    my @children  = $elem->children;
    my $file      = shift @children;
    my $fileName  = $file->att('name');

    for my $ch (@children) {
	my $name  = $ch->att('name');
	my $ccn   = $ch->att('ccn');
	my $ccn2  = $ch->att('ccn2');
	my $cloc  = $ch->att('cloc');
	my $eloc  = $ch->att('eloc');
	my $lloc  = $ch->att('lloc');
	my $loc   = $ch->att('loc');
	my $ncloc = $ch->att('ncloc');
	my $npath = $ch->att('npath');

        #print "$name: $ccn, $ccn2, $cloc, $eloc, $lloc, $loc, $ncloc, $npath \n"
    }

    # TODO: Populate Metric Object

    $bugObject->setBugMessage($message);
    $bugObject->setBugCode($source_rule);
    return $bugObject;
}

