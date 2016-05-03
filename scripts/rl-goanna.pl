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

my $twig = XML::Twig->new(
    twig_roots         => { 'results'  => 1 },
    twig_handlers      => { 'results/warning' => \&ParseWarning }
);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

my $locationId;
my $temp_input_file;
my $file_Id = 0;

foreach my $input_file (@input_file_arr) {
	$temp_input_file = $input_file;
	$file_Id++;
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub ParseWarning
{
    my ($tree,$elem) = @_;
    my ($beginLine,$endLine,$begincol,$endcol,$filepath,$bugcode,$bugmsg,$severity,$category, $bug_xpath, $method, $trace_block);
    
    $method   = $elem->first_child('method')->text;
    $filepath = $elem->first_child('absFile')->text;
    $filepath =  Util::AdjustPath($package_name, $cwd, $filepath);    
    $bugcode  =  $elem->first_child('checkName')->text;
    $beginLine = $elem->first_child('lineNo')->text;
    $endLine   = $beginLine;
    $begincol  = $elem->first_child('column')->text;
    $endcol    =  $elem->first_child('column')->text;
    $bugmsg    = $elem->first_child('message')->text;
    $severity  = $elem->first_child('severity')->text;
    $locationId = 0;
    
    my $bug_object = new bugInstance($xmlWriterObj->getBugId());
    $bug_object->setBugLocation(1,"",$filepath,$beginLine,$endLine,$begincol,$endcol,"",'true','true');
    $bug_object->setBugMessage($bugmsg);
    $bug_object->setBugSeverity($severity);
    $bug_object->setBugCode($bugcode);
    $locationId++;
    $bug_object->setBugBuildId($build_id);
    $bug_object->setBugMethod($locationId,"","",$method,1);
    $bug_object->setBugReportPath(Util::AdjustPath( $package_name, $cwd, "$input_dir/$temp_input_file" ));
    $bug_object->setBugPath($elem->path() . "[" . $file_Id . "]" . "/warning[" . $xmlWriterObj->getBugId()-1 . "]" );
    $trace_block = $elem->first_child('trace');
    foreach my $traceblock_tr ($trace_block->children('traceBlock'))
    {
        my $file = $traceblock_tr->att('file');
        my $method = $traceblock_tr->att('method');
        $bug_object = traceline($traceblock_tr,$file,$bug_object);
    }
    $xmlWriterObj->writeBugObject($bug_object);
}

sub traceline
{
    my $elem = shift;
    my $file = shift;
    my $method = shift;
    my $bug_object = shift;
    foreach my $traceline ($elem->children('traceLine'))
    {
         $locationId++;
         $bug_object->setBugLocation($locationId,$method,$file,$traceline->att('line'),$traceline->att('line'),0, 0,$traceline->att('text'),'false','true');
    }
    return $bug_object;
}
