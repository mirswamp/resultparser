#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;
use 5.010;

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
        twig_handlers =>
        {
            '/CCCC_Project/procedural_summary/module' => \&modules,
            'project_summary' => \&summary,
        }
);


#Initialize the counter values
my $bugId       = 0;
my $file_Id     = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my %h;

foreach my $input_file (@input_file_arr) {
	%h = hash();
    $twig->parsefile("$input_dir/$input_file");
    undef %h;
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub summary{
    my ($twig, $rev) = @_;
    my $root    = $twig->root;
    my @nodes   = $root->descendants;
    my $line    = $twig->{twig_parser}->current_line;
    my $col     = $twig->{twig_parser}->current_column;

    my $nm = $twig->first_elt( 'number_of_modules' )->att('value');
    my $lc = $twig->first_elt( 'lines_of_code' )->att('value');
    my $lcm = $twig->first_elt( 'lines_of_code_per_module' )->att('value');
    my $mcc = $twig->first_elt( 'McCabes_cyclomatic_complexity' )->att('value');
    my $mcm = $twig->first_elt( 'McCabes_cyclomatic_complexity_per_module' )->att('value');
    my $loc = $twig->first_elt( 'lines_of_comment' )->att('value');
    my $locm = $twig->first_elt( 'lines_of_comment_per_module' )->att('value');
    my $loclc = $twig->first_elt( 'lines_of_code_per_line_of_comment' )->att('value');
    my $mcclc = $twig->first_elt( 'McCabes_cyclomatic_complexity_per_line_of_comment' )->att('value');
    
    $h{ 'summary' }{'number_of_modules'} = $nm;
    $h{ 'summary' }{'lines_of_code'} = $lc;
    $h{ 'summary' }{'lines_of_code_per_module'} = $lcm;
    $h{ 'summary' }{'McCabes_cyclomatic_complexity'} = $mcc;
    $h{ 'summary' }{'McCabes_cyclomatic_complexity_per_module'} = $mcm;
    $h{ 'summary' }{'lines_of_comment'} = $loc;
    $h{ 'summary' }{'lines_of_comment_per_module'} = $locm;
    $h{ 'summary' }{'lines_of_code_per_line_of_comment'} = $loclc;
    $h{ 'summary' }{'McCabes_cyclomatic_complexity_per_line_of_comment'} = $mcclc;
    $h{ 'summary' }{'MLocation'}{'line'} = $line;
    $h{ 'summary' }{'MLocation'}{'column'} = $col;
    
    $xmlWriterObj->writeMetricObject( $h{ 'summary' } );

}

sub modules{
    my ($twig, $mod) = @_;
    my $root    = $twig->root;
    my @nodes   = $root->descendants;
    my $line    = $twig->{twig_parser}->current_line;
    my $col     = $twig->{twig_parser}->current_column;

    state $counter  = 0;

    my $name  = $mod->first_child('name')->text;
    my $loc = $mod->first_child('lines_of_code')->att('value');
    my $mcc = $mod->first_child('McCabes_cyclomatic_complexity')->att('value');
    my $lom = $mod->first_child('lines_of_comment')->att('value');
    my $locplc = $mod->first_child('lines_of_code_per_line_of_comment')->att('value');
    my $mcclm = $mod->first_child('McCabes_cyclomatic_complexity_per_line_of_comment')->att('value');
    $h{ $counter }{'name'} = $name;
    $h{ $counter }{'lines_of_code'} = $loc;
    $h{ $counter }{'McCabes_cyclomatic_complexity'} = $mcc;
    $h{ $counter }{'lines_of_comment'} = $lom;
    $h{ $counter }{'lines_of_code_per_line_of_comment'} = $locplc;
    $h{ $counter }{'McCabes_cyclomatic_complexity_per_line_of_comment'} = $mcclm;
    $h{ $counter }{'MLocation'}{'line'} = $line;
    $h{ $counter }{'MLocation'}{'column'} = $col;
    $xmlWriterObj->writeMetricObject( $h{ $counter } );
    $counter++;
}

