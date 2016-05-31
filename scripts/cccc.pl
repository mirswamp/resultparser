#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;
use 5.010;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile,
	$help, $version);

GetOptions(
	"input_dir=s"           => \$inputDir,
	"output_file=s"         => \$outputFile,
	"tool_name=s"           => \$toolName,
	"summary_file=s"        => \$summaryFile,
	"weakness_count_file=s" => \$$weaknessCountFile,
	"help"                  => \$help,
	"version"               => \$version
) or die("Error");

Util::Usage()   if defined $help;
Util::Version() if defined $version;

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion,
	@inputFiles) = Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;

my $twig = XML::Twig->new(
	twig_handlers => {
		'/CCCC_Project/procedural_summary/module' => \&modules,
		'project_summary'                         => \&summary,
	}
    );

#Initialize the counter values
my $bugId   = 0;
my $fileId = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);
my %h;

foreach my $inputFile (@inputFiles)  {
    %h        = hash();
    $buildId = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
    undef %h;
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub summary {
    my ($twig, $rev) = @_;

    my $root  = $twig->root;
    my @nodes = $root->descendants;
    my $line  = $twig->{twig_parser}->current_line;
    my $col   = $twig->{twig_parser}->current_column;

    my $nm  = $twig->first_elt('number_of_modules')->att('value');
    my $lc  = $twig->first_elt('lines_of_code')->att('value');
    my $lcm = $twig->first_elt('lines_of_code_per_module')->att('value');
    my $mcc = $twig->first_elt('McCabes_cyclomatic_complexity')->att('value');
    my $mcm = $twig->first_elt('McCabes_cyclomatic_complexity_per_module')->att('value');
    my $loc  = $twig->first_elt('lines_of_comment')->att('value');
    my $locm = $twig->first_elt('lines_of_comment_per_module')->att('value');
    my $loclc = $twig->first_elt('lines_of_code_per_line_of_comment')->att('value');
    my $mcclc = $twig->first_elt('McCabes_cyclomatic_complexity_per_line_of_comment')->att('value');

    $h{'summary'}{'number_of_modules'}                                 = $nm;
    $h{'summary'}{'lines_of_code'}                                     = $lc;
    $h{'summary'}{'lines_of_code_per_module'}                          = $lcm;
    $h{'summary'}{'McCabes_cyclomatic_complexity'}                     = $mcc;
    $h{'summary'}{'McCabes_cyclomatic_complexity_per_module'}          = $mcm;
    $h{'summary'}{'lines_of_comment'}                                  = $loc;
    $h{'summary'}{'lines_of_comment_per_module'}                       = $locm;
    $h{'summary'}{'lines_of_code_per_line_of_comment'}                 = $loclc;
    $h{'summary'}{'McCabes_cyclomatic_complexity_per_line_of_comment'} = $mcclc;
    $h{'summary'}{'MLocation'}{'line'}                                 = $line;
    $h{'summary'}{'MLocation'}{'column'}                               = $col;

    $xmlWriterObj->writeMetricObject($h{'summary'});
}


sub modules {
    my ($twig, $mod) = @_;

    my $root  = $twig->root;
    my @nodes = $root->descendants;
    my $line  = $twig->{twig_parser}->current_line;
    my $col   = $twig->{twig_parser}->current_column;

    state $counter = 0;

    my $name = $mod->first_child('name')->text;
    my $loc  = $mod->first_child('lines_of_code')->att('value');
    my $mcc  = $mod->first_child('McCabes_cyclomatic_complexity')->att('value');
    my $lom  = $mod->first_child('lines_of_comment')->att('value');
    my $locplc = $mod->first_child('lines_of_code_per_line_of_comment')->att('value');
    my $mcclm = $mod->first_child('McCabes_cyclomatic_complexity_per_line_of_comment')->att('value');
    $h{$counter}{'name'}                                              = $name;
    $h{$counter}{'lines_of_code'}                                     = $loc;
    $h{$counter}{'McCabes_cyclomatic_complexity'}                     = $mcc;
    $h{$counter}{'lines_of_comment'}                                  = $lom;
    $h{$counter}{'lines_of_code_per_line_of_comment'}                 = $locplc;
    $h{$counter}{'McCabes_cyclomatic_complexity_per_line_of_comment'} = $mcclm;
    $h{$counter}{'MLocation'}{'line'}                                 = $line;
    $h{$counter}{'MLocation'}{'column'}                               = $col;
    $xmlWriterObj->writeMetricObject($h{$counter});
    $counter++;
}
