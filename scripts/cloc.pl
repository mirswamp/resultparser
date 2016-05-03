#!/usr/bin/perl -w
use strict;
use warnings;
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

my $twig = XML::Twig->new(
    twig_roots=> { 'files/file'=> \&metrics }
);


#Initialize the counter values
my $bugId       = 0;
my $file_Id     = 0;
my %h;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeMetricObjectUtil(%h);
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}

sub metrics {
	my ( $twig, $rev ) = @_;
	my $root = $twig->root;
	my @nodes = $root->descendants;
	my $line = $twig->{twig_parser}->current_line;
	my $col = $twig->{twig_parser}->current_column;
	
	foreach my $n (@nodes) {
		my $comment = $n->{'att'}->{'comment'};
		my $code = $n->{'att'}->{'code'};
        my $blank = $n->{'att'}->{'blank'};
        my $total = $comment + $code + $blank;
        my $sourcefile = $n->{'att'}->{'name'};
        my $language = $n->{'att'}->{'language'};
        $h{ $sourcefile }{'func-stat'} = "";
        $h{ $sourcefile }{'file-stat'}{'file'} = $sourcefile;
        $h{ $sourcefile }{'file-stat'}{'location'}{'startline'} = "";
        $h{ $sourcefile }{'file-stat'}{'location'}{'endline'} = "";
        $h{ $sourcefile }{'file-stat'}{'metrics'}{'code-lines'} = $code;
        $h{ $sourcefile }{'file-stat'}{'metrics'}{'blank-lines'} = $blank;
        $h{ $sourcefile }{'file-stat'}{'metrics'}{'comment-lines'} = $comment;
        $h{ $sourcefile }{'file-stat'}{'metrics'}{'total-lines'} = $total;
        $h{ $sourcefile }{'file-stat'}{'metrics'}{'language'} = $language;
	}
}