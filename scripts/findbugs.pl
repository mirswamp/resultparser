#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ($input_file, $output_file, $tool_name, $tool_version, $uuid, $package_name, $build_id, $cwd, $replace_dir, $file_path);
my $violationId=0;
my $bugId = 0;
my $file_Id = 0;


GetOptions(
            "input_file=s" => \$input_file,
            "output_file=s" => \$output_file,
            "tool_name=s" => \$tool_name,
            "tool_version=s" => \$tool_version,
            "package_name=s" => \$package_name,
            "uuid=s" =>\$uuid,
            "build_id=s" => \$build_id,
            "cwd=s" => \$cwd,
            "replace_dir=s" => \$replace_dir,
            "input_file_arr=s"=>\@input_file_arr
            ) or die ("Error" );


my $cwe_xpath = 'BugCollection/BugPattern';
my $category_xpath = 'BugCollection/BugCategory';
my $source_xpath = 'BugCollection/Project/SrcDir';
my $xpath1 = 'BugCollection/BugInstance';

my $twig = XML::Twig->new(
                twig_roots=>{$xpath1=>1,
                	         $cwe_xpath=>1, 
                	         $category_xpath=>1,
                	         $source_xpath=>1,
                	          },
                twig_handlers=>{
                	$xpath1=>\&parseViolations,
                	$cwe_xpath=>\&parseBugPattern,
                	$source_xpath=>\&parseSourcePath,
                	$category_xpath=>\&parseBugCategory
                });
                
my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag($tool_name, $tool_version, $uuid);

foreach my $input_file (@input_file_arr){
	$twig->parsefile($input_file);
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub parseViolations
{
    my($tree,$elem)=@_;
    
    my $bug_xpath=$elem->path();
    
    my $bugObject = getFindBugsBugObject( $elem,$xmlWriterObj->getBugId(), $bug_xpath );
    $elem->purge() if defined($elem);
    
    $xmlWriterObj->writeBugObject($bugObject);
}

sub getFindBugsBugObject()
{
    my $elem = shift;
    my $bugId = shift;
    my $bug_xpath = shift;
    my ($bugcode, $bugmsg, $severity, $category, $priority, $summary, $explanation, $error_line, @tokens,$length);
    
    my $bugObject = new bugInstance($bugId);
    $bugObject->setBugReportPath(Util::AdjustPath($input_file));
    $bugObject->setBugBuildId($build_id);
    $bugObject->setBugSeverity($elem->att('priority'));
    $bugObject->setBugRank($elem->att('rank'));
    $bugObject->setBugPath($elem->att('path')."[".$bugId."]");
    
    $bugcode  = $elem->att('id');
    $severity = $elem->att('severity');
    $bugmsg   = $elem->att('message');
    $category = $elem->att('category');
    $priority = $elem->att('priority');
    $summary  = $elem->att('summary');
    $explanation = $elem->att('explanation');
    $error_line = $elem->att('errorLine2');
    if(defined ($error_line))
    { 
        @tokens   = split ('(\~)',$error_line);
    }
    $length = ($#tokens + 1)/2 ;
    ###################
    $bugObject->setBugMessage($bugmsg);

    $bugObject->setBugGroup($category);
    $bugObject->setBugCode($bugcode);
    $bugObject->setBugSuggestion($summary);
    $bugObject->setBugPath($bug_xpath."[$bugId]");

    my $location_num = 0;
    foreach my $child_elem ($elem->children)
    {
        if ($child_elem->gi eq "location")
        {
            my $filepath = Util::AdjustPath($package_name, $cwd, $child_elem->att('file'));
            my $line_num = $child_elem->att('line');
            my $begin_col = $child_elem->att('column'); 
            my $end_col;
            if ($length >= 1){$end_col = $begin_col+$length;}
            else {$end_col = $begin_col;}
            $bugObject->setBugLocation(++$location_num,"",$filepath,$line_num,$line_num,$begin_col,$end_col,$explanation,'true','true');
            }
        else
        {
            print "found an unknown tag: ".$child_elem->gi;
        }
    }
    return $bugObject;
}




