#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my (
    $input_dir,  $output_file,  $tool_name, $summary_file
);

GetOptions(
    "input_dir=s"   => \$input_dir,
    "output_file=s"  => \$output_file,
    "tool_name=s"    => \$tool_name,
    "summary_file=s" => \$summary_file
) or die("Error");

if( !$tool_name ) {
    $tool_name = Util::GetToolName($summary_file);
}

my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser($summary_file);

my $file_xpath_stdviol='ResultsSession/CodingStandards/StdViols/StdViol';
my $file_xpath_dupviol='ResultsSession/CodingStandards/StdViols/DupViol';
my $file_xpath_flowviol='ResultsSession/CodingStandards/StdViols/FlowViol';

my $twig = XML::Twig->new(
    twig_roots         => { 'ResultsSession'  => 1 },
    twig_handlers      => { $file_xpath_stdviol => \&ParseViolations_StdViol,
    	                    $file_xpath_dupviol => \&ParseViolations_DupViol,
    	                    $file_xpath_flowviol => \&ParseViolations_FlowViol }
);


#Initialize the counter values
my $bugId       = 0;
my $file_Id     = 0;
my $stdviol_num;
my $dupviol_num;
my $flowviol_num;
my @tokens = split("::",$replace_dir);
my $target = $tokens[0];
my @srcdir = @tokens[1..$#tokens];

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	$stdviol_num = 0;
	$dupviol_num = 0;
	$flowviol_num = 0;
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub ParseViolations_StdViol
{
    my ( $tree, $elem ) = @_;
    my ( $beginLine, $endLine, $begincol, $endcol, $filepath, $bugcode, $bugmsg, $severity, $category, $bug_xpath);
    $beginLine=$elem->att('ln');
    $endLine=$beginLine;
    $stdviol_num++;
    $filepath = replacePaths($elem->att('locFile'));
    $filepath =  Util::AdjustPath($package_name, $cwd, "$input_dir/$input");
    $bugcode = $elem->att('rule');
    $bugmsg = $elem->att('msg');
    $severity=$elem->att('sev');
    $category = $elem->att('cat');
    $bug_xpath = $elem->path();
    my $bugObject = new bugInstance($xmlWriterObj->getBugId());
    $bugObject->setBugLocation(1,"",$filepath,$beginLine,$endLine,"0","0","",'true','true');
    $bugObject->setBugMessage($bugmsg);
    $bugObject->setBugSeverity($severity);
    $bugObject->setBugGroup($category);
    $bugObject->setBugCode($bugcode);
    $bugObject->setBugPath($bug_xpath."[$stdviol_num]");
    $bugObject->setBugBuildId($build_id);
    $bugObject->setBugReportPath(Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ));
    $xmlWriterObj->writeBugObject($bugObject);
    $tree->purge();
}

sub ParseViolations_DupViol
{   
    my ( $tree, $elem ) = @_;
    my ( $beginLine, $endLine, $begincol, $endcol, $filepath, $bugcode, $bugmsg, $severity, $category, $bug_xpath); 
    $locationId = 1;
    $bugcode  = $elem->att('rule');
    $bugmsg   = $elem->att('msg');
    $severity = $elem->att('sev');
    $category = $elem->att('cat');
    $bug_xpath = $elem->path();
    foreach my $child_elem ($elem->first_child('ElDescList')->children)
    {
        $dupviol_num++;
        my $bugObject = new bugInstance($xmlWriterObj->getBugId());
        $filepath = replacePaths($child_elem->att('srcRngFile'));
        $filepath = Util::AdjustPath($package_name,$cwd,$filepath);
        $beginLine = $child_elem->att('srcRngStartln');
        $endLine = $child_elem->att('srcRngEndLn');
        $begincol = $child_elem->att('srcRngStartPos');
        $endcol = $child_elem->att('srcRngEndPos');
        $bugObject->setBugMessage($bugmsg);
        $bugObject->setBugSeverity($severity); 
        $bugObject->setBugGroup($category);    
        $bugObject->setBugCode($bugcode);      
        $bugObject->setBugPath($bug_xpath."[$dupviol_num]");
        $bugObject->setBugBuildId($build_id);
        $bugObject->setBugReportPath($input_file);
        my $locnmsg = $child_elem->att('desc') ;
        $bugObject->setBugLocation($locationId,"",$filepath,$beginLine,$endLine,$begincol,$endcol,"",$locnmsg,'false','true');
        $xmlWriterObj->writeBugObject($bugObject);
    }
    $tree->purge();
}

sub ParseViolations_FlowViol
{
    my ( $tree, $elem ) = @_;
    my ( $beginLine, $endLine, $begincol, $endcol, $filepath, $bugcode, $bugmsg, $severity, $category, $bug_xpath);
    $locationId = 1;    
    $flowviol_num++;
    $beginLine= $elem->att('ln');
    $endLine  = $beginLine;
    $filepath = replacePaths($elem->att('locFile'));
    $filepath = Util::AdjustPath($package_name,$cwd,$filepath);
    $bugcode  = $elem->att('rule');
    $bugmsg   = $elem->att('msg');
    $severity = $elem->att('sev');
    $bug_xpath = $elem->path();
    my $bugObject = new bugInstance($xmlWriterObj->getBugId());
    $bugObject->setBugLocation(1,"",$filepath,$beginLine,$endLine,"0","0","",'true','true');
    $bugObject->setBugMessage($bugmsg);
    $bugObject->setBugSeverity($severity);
    $bugObject->setBugGroup($category);
    $bugObject->setBugCode($bugcode);
    $bugObject->setBugPath($bug_xpath."[$flowviol_num]");
    $bugObject->setBugBuildId($build_id);
    $bugObject->setBugReportPath($input_file);

    foreach my $child_elem ($elem->children)
    {
        if ($child_elem->gi eq "ElDescList")
        {
            parseElDescList($child_elem, $bugObject);
        }
    }
    $xmlWriterObj->writeBugObject($bugObject);
}

sub parseElDescList
{
    my ($elem, $bugObject) = @_;
    foreach my $child_elem ($elem->children)
    {
        if ($child_elem->gi eq "ElDesc")
        {
            parseElDesc($child_elem, $bugObject);
        }
    }
}

sub parseElDesc
{
    my $elem = shift;
    my $bugObject = shift;
    my ($beginLine, $endLine, $begincol, $endcol, $filepath, $locnmsg);
    $locationId++;  
    $beginLine = $elem->att('ln');
    if (defined $elem->att('eln')){$endLine = $elem->att('eln');}
    else {$endLine = $beginLine;}
    $filepath = replacePaths($elem->att('srcRngFile'));
    $filepath = Util::AdjustPath($package_name,$cwd,$filepath);
    $locnmsg = $elem->att('desc');
    if ($elem->att('ElType') ne ".P")   
    {
        $bugObject->setBugLocation($locationId,"",$filepath,$beginLine,$endLine,"0","0",$locnmsg,'false','true');
    }
    foreach my $child_elem ($elem->children)
    {
        if ($child_elem->gi eq "ElDescList")
        {
            parseElDescList($child_elem, $bugObject);
        }
    }   
}

sub replacePaths
{
    my $file_path = shift;
    foreach my $dir (keys %replace_paths)
    {
        my $search_path = $target."/".$dir;
        if ($file_path =~ /$search_path/)
        {
            $file_path =~ s/$search_path/$replace_paths{$dir}/;
            if (-e $file_path)
            {
                last;
            }
        }
    }
return $file_path;
}