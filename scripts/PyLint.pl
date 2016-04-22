#!/usr/bin/perl -w

use strict;
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

#Initialize the counter values
my $bugId       = 0;
my $file_Id     = 0;

my %severity_hash = ('C'=>'Convention','R'=>'Refactor','W'=>'Warning','E'=>'Error','F'=>'Fatal','I'=>'Information');

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
    open (my $fh, "<", "$input_dir/$input_file") or die "input file not found\n";
    my $msg = " ";
    my $temp_bug_object;
    while ( <$fh> ) {
    	my ( $file, $line_num, $bug_code, $bug_ex, $bug_msg );
    	my $line = $_;
    	chomp($line);
    	if( $line =~ /^Report$/ ){
    		last;
    	}
    	if (!($line =~ /^\*\*\*\*\*\*\*\*\*\*\*\*\*/) && !($line =~ /^$/))                         ## checking for comment line or empty line
        {
            ($file,$line_num,$bug_code,$bug_ex,$bug_msg) = ParseLine($line);
            if ($file eq "invalid_line")
            {   $msg = $msg."\n".$line;
            	print "\n*** invalid line";
            	if(defined $temp_bug_object){
                    $temp_bug_object->setBugMessage($msg);
            	} 
            }
            else
            {
                my $bug_object = new bugInstance($xmlWriterObj->getBugId());
                if(defined $temp_bug_object){
                	$xmlWriterObj->writeBugObject($temp_bug_object);
                }
                my $bug_severity = SeverityDet(substr($bug_code,0,1));
                $bug_object->setBugLocation(1,"",$file,$line_num,$line_num,0,0,"",'true','true');
                $msg = $bug_object->setBugMessage($bug_msg);
                $bug_object->setBugSeverity($bug_severity);
                $bug_object->setBugCode($bug_code);
                $bug_object->setBugBuildId($build_id);
                $bug_object->setBugReportPath(Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ));
                $temp_bug_object = $bug_object;
            }
        }
    }
    if(defined $temp_bug_object){
        $xmlWriterObj->writeBugObject($temp_bug_object);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();


sub ParseLine
{
    my $line = shift;
    my @tokens1 = split(":",$line);
    if ($#tokens1 < 2)
    {
        return "invalid_line";
    }
    my $file =  Util::AdjustPath($package_name, $cwd, $tokens1[0]);
    my $line_num = $tokens1[1];
    my $line_trim = $tokens1[2];                                              ## code to join rest of the message (this is done to recover from unwanted split due to : present in message)
    for (my $i = 3; $i <= $#tokens1; $i++)                    #
    {                                     # 
        $line_trim = $line_trim.":".$tokens1[$i];             #
    }                                     #
    $line_trim =~ /\[(.*?)\](.*)/;
    my $bug_des = $1;
    my $bug_msg = $2;
    $bug_msg =~ s/^\s+//;
    $bug_msg =~ s/\s+$//;
    my ($bug_code,$bug_ex);
    ($bug_code,$bug_ex) = split(",",$bug_des);
    $bug_code =~ s/^\s+//;
    $bug_code =~ s/\s+$//;
    $bug_ex =~ s/^\s+//;
    $bug_ex =~ s/\s+$//;
    return ($file,$line_num,$bug_code,$bug_ex,$bug_msg);
}

sub SeverityDet
{
    my $char = shift;
    if (exists $severity_hash{$char})
    {
        return($severity_hash{$char});
    }
    else
    {
        die "Unknown Severity $char";
    }   
}

