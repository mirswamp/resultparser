#! /usr/bin/perl

use strict;
use Twig;
use Data::Dumper;
use Getopt::Long;
use Switch;

my $file1;
my $file2;
my $output;
my $tag_elem;
my $result = GetOptions ('file1=s' => \$file1,
			 'file2=s' => \$file2,
			 'output=s' => \$output,
			 'tag_elements=s' => \$tag_elem);

if (!defined($output))
{
	$output = "diff_out";
}
print "???????????????starting the script????????????\n";
print "$file1 and $file2\n";
open(my $fh,"<",$file2) or die ("file not found");
open(my $fh_out,">",$output) or die ("cannot create output file");

###############################################################parsing file1#########################################################################################
my $count_xml = 0;
my %hash_xml;
my %hash_csv;
my %hash_xml2;
my $count_dup = 0;
my $count_csv = 0;

my $xpath = "BugInstance";  
my $twig = new XML::Twig(TwigHandlers => {
                                        $xpath => \&parse_routine
                                           });

$twig->parsefile($file1);

my $twig2 = new XML::Twig(TwigHandlers => {
                                          $xpath => \&parse_routine2
                                         });
$twig2->parsefile($file2);



sub parse_routine {
  my $start_line;
  my $end_line;
  my $start_col;
  my $end_col;
  my $assessment_file;
  my $location_start_line;
  my $location_end_line;
  my ($tree,$elem) = @_;
  my $file_name = $elem->first_child('BugLocations')->first_child('Location')->first_child('SourceFile')->field;
  $file_name = lc($file_name);
  $file_name =~ s/(.*?)\///;
  if ( $elem->first_child('BugLocations')->first_child('Location')->first_child('StartLine') != 0)
  {
      $start_line = $elem->first_child('BugLocations')->first_child('Location')->first_child('StartLine')->field;
  }
  else
  {
      $start_line = 'NA';
  }
  
  if ($elem->first_child('BugLocations')->first_child('Location')->first_child('EndLine') != 0)
  {
      $end_line = $elem->first_child('BugLocations')->first_child('Location')->first_child('EndLine')->field;
  }
  else
  {
       $end_line = 'NA';
  }
  my $bug_code;
  if ($elem->first_child('BugCode') != 0)
  {
  	$bug_code = $elem->first_child('BugCode')->field;
  	$bug_code = lc($bug_code);
  }


  if ($elem->first_child('BugLocations')->first_child('Location')->first_child('StartColumn') != 0)
  {
        $start_col = $elem->first_child('BugLocations')->first_child('Location')->first_child('StartColumn')->field;
  }
  else
  {
        $start_col = 'NA';
   }

   if ($elem->first_child('BugLocations')->first_child('Location')->first_child('EndColumn') != 0)
   {
           $end_col = $elem->first_child('BugLocations')->first_child('Location')->first_child('EndColumn')->field;
   }
   else
   {
           $end_col = 'NA';
   }

  if ($tag_elem > 6)
  {
      if ($elem->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('Start') != 0)
      {
            $location_start_line = $elem->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('Start')->field;
      }
      else
      {
            $location_start_line = 'NA';
      }
      
      if ($elem->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('End') != 0)
      {
            $location_end_line = $elem->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('End')->field;
      }
      else
      {
            $location_end_line = 'NA';
      }
  }

  if ($elem->first_child('BugTrace')->first_child('AssessmentReportFile') != 0)
  {
       $assessment_file = $elem->first_child('BugTrace')->first_child('AssessmentReportFile')->field;
  }
  else
  {
       $assessment_file = "NA";	
  }

  my $location = $elem->first_child('BugLocations')->first_child('Location')->{'att'}->{primary};
  my $bug_id  = $elem->{'att'}->{id};
  my $bug_msg;
  if ($elem->first_child('BugMessage') != 0)
  {
  	$bug_msg = $elem->first_child('BugMessage')->field;
  	$bug_msg =~ s/"//g; 
  	$bug_msg = lc ($bug_msg);
  	$bug_msg =~ s/\s+$//;
  }
  my $tag;
  switch ($tag_elem)
  {
        case "7" {$tag = $file_name.':'.$start_line.":".$end_line.":".$start_col.":".$end_col.":".$bug_code.":".$bug_msg.":".$location_start_line.":".$location_end_line.":".$assessment_file}
	case "6" {$tag = $file_name.':'.$start_line.":".$end_line.":".$start_col.":".$end_col.":".$bug_code.":".$bug_msg.":".$assessment_file}
  	case "5" {$tag = $file_name.':'.$start_line.":".$end_line.":".$start_col.":".$end_col.":".$bug_code.":".$bug_msg}
	case "4" {$tag = $file_name.':'.$start_line.":".$end_line.":".$start_col.":".$end_col.":".$bug_code}
        case "3" {$tag = $file_name.':'.$start_line.":".$end_line.":".$start_col.":".$end_col}
	case "2" {$tag = $file_name.':'.$start_line.":".$end_line}
	case "1" {$tag = $file_name}
  }

if (!exists($hash_xml{$tag}))
{
     $hash_xml{$tag} = {'count'=>1,'bugid'=>$bug_id, 'startline'=>$start_line, 'endline'=>$end_line, 'location'=>$location};
     $count_xml++;
}
else
{
     $hash_xml{$tag}->{count} = $hash_xml{$tag}->{count}+1;
     $hash_xml{$tag}->{bugid} = $hash_xml{$tag}->{bugid}."\n\t".$bug_id;
     $count_dup++;	
}
 $tree->purge;

}
########################################################################parsing CSV as XML###########################################################################################################################################


sub parse_routine2 {	
	my $start_line_csv;
	my $end_line_csv;
	my $start_col_csv;
	my $end_col_csv;
	my $location_start_line_csv;
  	my $location_end_line_csv;
	my $assessment_file_csv;
	my ($tree_csv,$elem_csv) = @_;
	if ($elem_csv->first_child('BugLocations') == 0){
		next;
  	}
	my $file_name_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('SourceFile')->field;
  	$file_name_csv = lc($file_name_csv);
	$file_name_csv =~ s/(.*?)\///;
	if ( $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartLine') != 0)
  	{
      		$start_line_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartLine')->field;
  	}
  	else
  	{
      		$start_line_csv = 'NA';
  	}
	if ($elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndLine') != 0)
  	{
      		$end_line_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndLine')->field;
  	}
  	else
  	{
       		$end_line_csv = 'NA';
  	}
        if ($elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartColumn') != 0)
        {
		$start_col_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartColumn')->field;
	}
  	else
  	{
       		$start_col_csv = 'NA';
  	}
 
        if ($elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndColumn') != 0)
	{
	        $end_col_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndColumn')->field;
	}
	else
	{
	        $end_col_csv = 'NA';
	}
	if ($tag_elem > 6)
	{
	    if ($elem_csv->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('Start') != 0)
 	    {
	           $location_start_line_csv = $elem_csv->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('Start')->field;
	    }
	    else
	    {
	          $location_start_line_csv = 'NA';
	    }
	    
	    if ($elem_csv->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('End') != 0)
	    {
	          $location_end_line_csv = $elem_csv->first_child('BugTrace')->first_child('InstanceLocation')->first_child('LineNum')->first_child('End')->field;
	    }
	    else
	    {
	    	$location_end_line_csv = 'NA';
	    }
 	}

	if ($elem_csv->first_child('BugTrace')->first_child('AssessmentReportFile') != 0)
	{
		$assessment_file_csv = $elem_csv->first_child('BugTrace')->first_child('AssessmentReportFile')->field;
   	}
   	else
   	{
		$assessment_file_csv = "NA";	
   	}
	
   	my $bug_code_csv;
	if ($elem_csv->first_child('BugCode') != 0)
	{
		$bug_code_csv = $elem_csv->first_child('BugCode')->field;
  		$bug_code_csv = lc($bug_code_csv);
	}
  	my $location_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->{'att'}->{primary};
  	my $bug_id_csv  = $elem_csv->{'att'}->{id};
  	my $bug_msg_csv;
	if ($bug_msg_csv = $elem_csv->first_child('BugMessage') != 0)
	{
		$bug_msg_csv = $elem_csv->first_child('BugMessage')->field;
  		$bug_msg_csv =~ s/"//g; 
  		$bug_msg_csv = lc ($bug_msg_csv);
  		$bug_msg_csv =~ s/\s+$//;
	}
        my $tag_csv;
	switch ($tag_elem)
  	{
        case "7" {$tag_csv = $file_name_csv.':'.$start_line_csv.":".$end_line_csv.":".$start_col_csv.":".$end_col_csv.":".$bug_code_csv.":".$bug_msg_csv.":".$location_start_line_csv.":".$location_end_line_csv.":".$assessment_file_csv}
	case "6" {$tag_csv = $file_name_csv.':'.$start_line_csv.":".$end_line_csv.":".$start_col_csv.":".$end_col_csv.":".$bug_code_csv.":".$bug_msg_csv.":".$assessment_file_csv}
  	case "5" {$tag_csv = $file_name_csv.':'.$start_line_csv.":".$end_line_csv.":".$start_col_csv.":".$end_col_csv.":".$bug_code_csv.":".$bug_msg_csv}
	case "4" {$tag_csv = $file_name_csv.':'.$start_line_csv.":".$end_line_csv.":".$start_col_csv.":".$end_col_csv.":".$bug_code_csv}
        case "3" {$tag_csv = $file_name_csv.':'.$start_line_csv.":".$end_line_csv.":".$start_col_csv.":".$end_col_csv}
	case "2" {$tag_csv = $file_name_csv.':'.$start_line_csv.":".$end_line_csv}
	case "1" {$tag_csv = $file_name_csv}
  	}
if ($hash_csv{$tag_csv} == 0)
{
     $hash_csv{$tag_csv} = {'count'=>1,'bugid'=>$bug_id_csv, 'startline'=>$start_line_csv, 'endline'=>$end_line_csv, 'location'=>$location_csv};
     $count_csv++;
}
else
{
     $hash_csv{$tag_csv}->{count} = $hash_csv{$tag_csv}->{count}+1;
     $hash_csv{$tag_csv}->{bugid} = $hash_csv{$tag_csv}->{bugid}.",".$bug_id_csv;
}
 $tree_csv->purge;
}	



###########################################################################parsing CSV#################################################################################################################################################
#
##print "######################################################\n";
##while (<$fh>)
##{
##	my $csv_line  = $_;
##	chomp ($csv_line);
##        #$csv_line =~ s/"//g;
##        my @csv_array = split('\",\"',$csv_line);
##        s/\\"//g for @csv_array;
##        s/"//g for @csv_array;
##        $csv_array[7] = lc($csv_array[7]);
##        $csv_array[8] = lc($csv_array[8]);
##        $csv_array[5] = lc($csv_array[5]);
#### WRITE A CASE STATEMENT FOR GENERATING CSV TAG IN A DIFFERENT WAY FOR DIFFERENT TOOLS 
##        my $csv_tag   = "yazd_1.0-src-swamp.1/source/com/yasna/".$csv_array[7].":".$csv_array[5].":".$csv_array[8];
###        print "$csv_tag\n"; 
##	if ($hash_csv{$csv_tag} == 0)
##	{
##   	   $hash_csv{$csv_tag} = {'count'=>1,'bugid'=>$csv_array[0]};
##	}
##	else
##	{
##   	   $hash_csv{$csv_tag}->{count} = $hash_csv{$csv_tag}->{count} + 1;
##	}	
##}
#
#
########################################################################comparsion####################################################################################################################################################
my $serial_number = 1;
my $total_difference = 0;
print $fh_out "Sno\tfile1_bug_num\tfile1_instances\tstart_line\tend_line\tfile2_bug_num\tfile2_instances\n";
my $elem_xml;
my $elem_csv2;
my $count_cmp = 0;
foreach my $elem_xml (keys %hash_xml)
{
   $count_cmp++;
   $elem_csv2 = $elem_xml;
   if (($hash_csv{$elem_csv2} == 0))
   {
	print $fh_out "$serial_number\.)\t$hash_xml{$elem_xml}->{bugid}\t\t$hash_xml{$elem_xml}->{count}\t\t$hash_xml{$elem_xml}->{startline}\t\t$hash_xml{$elem_xml}->{endline}\t\tNA\t\tNA\t\t$hash_xml{$elem_xml}->{location}\n";
        $serial_number++;
	$total_difference = $total_difference+$hash_xml{$elem_xml}->{count}; 
   }
   else
   {
	if(($hash_csv{$elem_csv2}->{count} != $hash_xml{$elem_xml}->{count}))
	{
	   print $fh_out "$serial_number\.)\t$hash_xml{$elem_xml}->{bugid}\t\t$hash_xml{$elem_xml}->{count}\t\t$hash_xml{$elem_xml}->{startline}\t\t$hash_xml{$elem_xml}->{endline}\t\t$hash_csv{$elem_csv2}->{bugid}\t\t$hash_csv{$elem_csv2}->{count}\t\t$hash_xml{$elem_xml}->{location}\n";
           $serial_number++;
	   $total_difference = $total_difference+$hash_xml{$elem_xml}->{count}-$hash_csv{$elem_csv2}->{count};
 	}
   }
}
print $fh_out "#########total differences found = $total_difference#########\n";
print $fh_out "#########total duplicates found in file1= $count_dup#########\n ";
close ($fh) or die ("unable to close the xml file");
close ($fh_out) or die ("unable to close the csv file");

