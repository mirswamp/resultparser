#!/usr/bin/perl

use strict;
use Getopt::Long;
use IO;
use Cwd;
use Twig;
use Archive::Extract;
use Archive::Tar;
use Archive::Zip;
use Archive::Zip::Tree;
use Switch;
use XML::Writer;
use bugInstance;

my ($input_dir,$package,$tool,$platform,$cwd,$package_name,$tool_version,$uuid,$tool_name,$build_id);
my $curwrkdir = getcwd;
my $bug_count = 0;
my %bughash;
my %bugassfile;
my $logfile = "log";
my ($report_path_cpp,$report_path_chst,$report_path_fb,$report_path_pmd,$bugcount_ep);
my $result = GetOptions('package=s' => \$package,
			'tool=s' => \$tool,
			'platform=s' => \$platform,
			'output=s' => \$logfile);

my ($pkg_defined, $platform_defined, $tool_defined) = 0;
if (defined ($package))
{
	$pkg_defined = 1;
}

if (defined($platform))
{
	$platform_defined = 1;
}

if (defined($tool))
{
	$tool_defined = 1
}

open (my $fh1,">",$logfile);
opendir my $dh, $curwrkdir or die "could not open the dir";

while (defined ($input_dir = readdir $dh))
{
	$bug_count = 0;
	$bugcount_ep = 0;
	%bughash = ();
	%bugassfile = ();
	my @tokens = split("---",$input_dir);
	if($#tokens != 3 | ($tokens[3] ne 'parse'))
	{
		next;
	}
	else
	{
		if((!($pkg_defined)|($tokens[0] eq $package)) && (!($platform_defined)|($tokens[1] eq $platform)) && (!($tool_defined)|($tokens[2] eq $tool)))
		{
			print $fh1 "#########$input_dir##############\n";
			print "##############working on $input_dir##############\n";
			my $run_successful = run_success($input_dir);
			if ($run_successful == 0)
			{
				print "the run $input_dir was not successfule\n";
				next;
			}
			my $input_path = $curwrkdir."/".$input_dir;
			my $results_dir = $input_path."/results";
			my $parsed_result = $input_path."/parsed_results";
			my $asm_path = $results_dir."/assessment_summary.xml";
			untar_results($results_dir);
			untar($input_path,$parsed_result);
			my @lines = `perl parseSummary.pl --summary_file=$asm_path`;
			for (my $i = 0;$i <= $#lines; $i++)
			{
				chomp($lines[$i]);
				my @tokens = split("~:~",$lines[$i]);
				my $report_path = $results_dir."/".$tokens[5]; 
				$tool_name = $tokens[2];
				$tool_version = $tokens[3];
				$build_id = $tokens[4];
				$package_name = $tokens[1];
				$cwd = $tokens[6];
				$uuid = $tokens[0];
				switch($tool_name)
				{
					case "cppcheck"   {cppcheck($report_path)}
					case "gcc-warn"   {gccwarn($report_path)}
					case "checkstyle" {checkstyle($report_path)}
					case "FindBugs"   {findbugs($report_path)}
					case "pmd"	  {pmd($report_path)}
					case "error-prone"{errorprone($report_path)}
					case "clang-sa"	  {clang($report_path)}
				}
			}
			PrintXML();
			print $fh1 "count is $bug_count\n";
			my $count_status = status_count();
			if ($count_status != $bug_count)
			{
				print $fh1 "*******COUNTS DO NOT MATCH*****\n";
	#			diff_scarf($parsed_result."/parsed_assessment_result.xml",$curwrkdir."/".$input_dir."_out.xml",$fh1,2);
				diff_scarf($curwrkdir."/".$input_dir."_out.xml",$parsed_result."/parsed_assessment_result.xml",$fh1,2);
			}
			print $fh1 "#################################\n";
		}
	}

}

$fh1->close;

################################cppcheck######################################################
sub cppcheck()
{
	my $report_path = shift;
	$report_path_cpp = $report_path;
	my $file_xpath = "results/errors/error";
	my $twig = new XML::Twig(TwigHandlers => {$file_xpath => \&cpp_parseError});	
	$twig->parsefile($report_path);
	$twig->purge();
}

sub cpp_parseError()
{
	my($tree,$elem) = @_;
	foreach my $error ($elem->children)
	{
		my $tag = $error->tag;
		if ($tag eq 'location')
		{
			$bug_count++;
			my $file_path = AdjustPath($package_name, $cwd,$error->att('file'));
			my $line_num = $error->att('line');
			my $bugObj = new bugInstance($bug_count);
			$bughash{$bug_count}=$bugObj;
			$bughash{$bug_count}->setBugLocation(0,"",$file_path,$line_num,$line_num,0,0,"","true","true");
			$bugassfile{$bug_count}=$report_path_cpp;

		}
	}
}
###############################################################################################

###############################clang###########################################################
sub clang()
{
	my $dir_path = shift;
	opendir my $directory, $dir_path or die "could not open the dir";
	while (defined (my $rf = readdir $directory))
	{
		if($rf =~ /^report.*.html$/)
		{
			open (my $fh_clang,"<",$dir_path."/".$rf) or die "file not found";
			my @lines = grep /<!--.*BUG.*-->/, <$fh_clang>;
			my ($filepath, $startline, $endline);
			foreach my $line (@lines)
			{
				chomp ($line);
				if ($line =~ m/.*BUGFILE/)
				{
					$bug_count++;
					$line =~ s/(<!--)//;
					$line =~ s/-->//;
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					my @tokens = split('\s',$line,2);
					$filepath = AdjustPath($package_name, $cwd, $tokens[1]);
				}
				
				if ($line =~ m/.*BUGLINE/)
				{
					$line =~ s/(<!--)//;
					$line =~ s/-->//;
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					my @tokens = split('\s',$line);
					$startline = $tokens[1];
					$endline = $tokens[1];
				}

	
			}
			my $bugObj = new bugInstance($bug_count);
			$bughash{$bug_count}=$bugObj;
			$bughash{$bug_count}->setBugLocation(0,"",$filepath,$startline,$endline,0,0,"","true","true");
			$bugassfile{$bug_count}=$dir_path."/".$rf;
			
		}
	}
}


###############################################################################################

#############################gccwarn###########################################################
sub gccwarn()
{
	my $report_path = shift;
	open(my $fh_op,"<","$report_path") or die "could not find the report\n";
	while(<$fh_op>)
	{
		my @tokens = split(":",$_);
		if (($#tokens == 4) && ($tokens[4] =~ /\[.*\]/))
		{
			$bug_count++;
			my $file_path = AdjustPath($package_name, $cwd, $tokens[0]);
			my $line_num = $tokens[1];
			my $bugObj = new bugInstance($bug_count);
			$bughash{$bug_count}=$bugObj;
			$bughash{$bug_count}->setBugLocation(0,"",$file_path,$line_num,$line_num,0,0,"","true","true");
			$bugassfile{$bug_count}=$report_path;
		}	
		
	}
}
################################################################################################


############################CHECKSTYLE##########################################################
sub checkstyle()
{
	my $report_path = shift;
	$report_path_chst = $report_path;
	my $file_xpath = 'checkstyle/file';
	my $twig = new XML::Twig(TwigHandlers=>{$file_xpath=>\&checkstyle_parse});
	$twig->parsefile($report_path);
	$twig->purge();
}


sub checkstyle_parse()
{
	my ($tree,$elem) = @_;
	my $filepath = AdjustPath($package_name, $cwd, $elem->att('name'));
	foreach my $bug ($elem->children)
	{
		$bug_count++;
		my $beginLine=$bug->att('line');
		my $endLine=$beginLine;
		my $bugcode=$bug->att('source');
		my $bugObj = new bugInstance($bug_count);
		$bughash{$bug_count}=$bugObj;
		$bughash{$bug_count}->setBugLocation(0,"",$filepath,$beginLine,$endLine,0,0,"","true","true");
		$bugassfile{$bug_count}=$report_path_chst;

	}
}
###############################################################################################


##########################FINDBUGS#############################################################
sub findbugs()

{
	my $report_path = shift;
	$report_path_fb = $report_path;
	my $file_xpath = 'BugCollection/BugInstance';
	my $twig = new XML::Twig(TwigHandlers=>{$file_xpath => \&findbugs_parse});
	$twig->parsefile($report_path);
	$twig->purge();
}

sub findbugs_parse()
{
	$bug_count++;
	my($tree,$elem) = @_;
	my $bug_code = $elem->att('type');
	foreach my $element ($elem->children)
	{
		my $tag = $element->gi;
		if($tag eq "SourceLine")
		{
			my $filepath = AdjustPath($package_name, $cwd,$element->att('sourcepath'));
			my $start_line = $element->att('start');
			my $end_line = $element->att('end');
			my $bugObj = new bugInstance($bug_count);
			$bughash{$bug_count}=$bugObj;
			$bughash{$bug_count}->setBugLocation(0,"",$filepath,$start_line,$end_line,0,0,"","true","true");
			$bugassfile{$bug_count}=$report_path_fb;

		} 
	}
}
##############################################################################################

############################PMD###############################################################

sub pmd
{
	my $report_path = shift;
	$report_path_pmd = $report_path;
	my $file_xpath = 'pmd/file';
	my $twig = new XML::Twig(TwigHandlers=>{$file_xpath=>\&pmd_parse});
	$twig->parsefile($report_path);
	$twig->purge();
}

sub pmd_parse()
{
	my ($tree,$elem) = @_;
	my $filepath = AdjustPath($package_name, $cwd,$elem->att('name'));
	foreach my $element ($elem->children)
	{
		$bug_count++;
		my $start_line = $element->att('beginline');
		my $endline    = $element->att('endline');
		my $bugcode    = $element->att('rule');
		my $bugObj = new bugInstance($bug_count);
		$bughash{$bug_count}=$bugObj;
		$bughash{$bug_count}->setBugLocation(0,"",$filepath,$start_line,$endline,0,0,"","true","true");
		$bugassfile{$bug_count}=$report_path_pmd;
	}
}

##############################################################################################


############################errorprone########################################################

sub errorprone
{
	my $report_path = shift;	
	open (my $fh2,"<","$report_path");
	my @lines;
	while (<$fh2>)
	{
		push(@lines,$_);
	}

	for (my $i = 0;$i <= $#lines;$i++)
	{
		my @tokens = split(":",$lines[$i]);
		if ($#tokens != 3 | !($tokens[3] =~ /^\s*\[.*\]/))
		{
			next;
		}
		else
		{	
			$bug_count++;
			my $filepath = AdjustPath($package_name, $cwd,$tokens[0]);
			my $startline = $tokens[1];
			my $endline = $startline;
			$tokens[3] =~ /^\s*\[(.*)\].*$/;
			my $bugcode = $1; 
			my $bugObj = new bugInstance($bug_count);
			$bughash{$bug_count}=$bugObj;
			$bughash{$bug_count}->setBugLocation(0,"",$filepath,$startline,$endline,0,0,"","true","true");
			$bughash{$bug_count}->setBugCode($bugcode);
			$bugassfile{$bug_count}=$report_path; 
		}
	}

	if ((($lines[$#lines]) =~ /error/) | ($lines[$#lines] =~ /warn/))
	{
		my @tokens = split("\s",$lines[$#lines]);
		$bugcount_ep = $bugcount_ep+$tokens[0];
	} 
	
	if ((($lines[$#lines-1]) =~ /error/) | ($lines[$#lines-1] =~ /warn/))
	{
		my @tokens = split("\s",$lines[$#lines-1]);
		$bugcount_ep = $bugcount_ep+$tokens[0];
	} 
	return;
	
}
##############################################################################################

###############################################################################################
sub NormalizePath
{
    my $p = shift;

    $p =~ s/\/\/+/\//g;                 # collapse consecutive /'s to one /
    $p =~ s/\/(\.\/)+/\//g;             # change /./'s to one /
    $p =~ s/^\.\///;                    # remove initial ./
    $p = '.' if $p eq '';               # change empty dirs to .
    $p =~ s/\/\.$/\//;                  # remove trailing . directory names
    $p =~ s/\/$// unless $p eq '/';     # remove trailing /

    return $p;
}

sub AdjustPath
{
    my ($baseDir, $curDir, $path) = @_;

    $baseDir = NormalizePath($baseDir);
    $curDir = NormalizePath($curDir);
    $path = NormalizePath($path);

    # if path is relative, prefix with current dir
    if ($path eq '.')  {
        $path = $curDir;
    }  elsif ($curDir ne '.' && $path !~ /^\//)  {
        $path = "$curDir/$path";
    }

    # remove initial baseDir from path if baseDir is not empty
    $path =~ s/^\Q$baseDir\E\///;

    return $path;
}

#####################################################################################################


#############################status.out################################################################
sub status_count
{
	my $status_out_path =  $curwrkdir."/".$input_dir."/status.out";
	
	open(my $fh,"<","$status_out_path") or die "status.out not found";
	while (<$fh>)
	{
		if($_ =~ /\(weaknesses: (.*)\)/)
		{
			print $fh1 "count in status.out is $1\n";
			return $1;
			last;
		}
	}
}

sub run_success()
{
	my $name = shift;
	my $status_path = $curwrkdir."/".$name."/status.out";
	open (my $fh,"<",$status_path) or return 0;
	while (<$fh>)
	{
		if($_ =~ /PASS: all/)
		{
			return 1;
		}
		
	}
	$fh->close;
	return 0;
}
######################################################################################################

###########################results dir################################################################

sub untar_results()
{
	my $path =  $curwrkdir."/".$input_dir;
	my $result_path = $path."/results";
	if(!(-d $result_path))
	{
		print "untarring the results directory\n";
		my $ae = Archive::Extract->new(archive=> $result_path.".tar.gz");
		$ae->extract(to=>$path);
	}
}

######################################################################################################

###################################untar##############################################################

sub untar()
{
	my $output_dir = shift;
	my $output = shift;
	if (!(-d $output))
	{
		print "untarring the parsed_result directory\n";
		my $ae = Archive::Extract->new(archive=> $output.".tar.gz");
		$ae->extract(to=>$output_dir);		
	}
}




######################################################################################################

###########################PrintXML###################################################################
sub PrintXML()
{
	my $output_file = $input_dir."_out.xml";
	open(my $oh,">",$output_file);
	my $writer = new XML::Writer(OUTPUT => $oh, DATA_MODE=>'true', DATA_INDENT=>2);
	$writer->xmlDecl('UTF-8');
	$writer->startTag('AnalyzerReport' ,'tool_name' => "$tool_name", 'tool_version' => "$tool_version", 'uuid'=> "$uuid");
	foreach my $object (sort{$a <=> $b} keys %bughash)
	{
		$bughash{$object}->printXML($writer,$bugassfile{$object},$build_id);
	}
        $writer->endTag();
        $writer->end();
        $oh->close();
}



###################################################################################################### diff script#######################################################################################################################
sub diff_scarf()
{
	my $file1 = shift;
	my $file2 = shift;
	my $fh_out = shift;
	my $tag_elem = shift;
	print "$file1 and $file2\n";
	open(my $fh,"<",$file2) or die ("file not found");
	
	#####################parsing file1######
	my $twig = XML::Twig->new();
	$twig->parsefile($file1);
	my $root = $twig->root;
	my @kids = $root->children;
	my $count_xml = 0;
	my %hash_xml;
	my %hash_csv;
	my %hash_xml2;
	my $count_dup = 0;
	my $start_line;
	my $end_line;
	foreach my $elem (@kids){
	  if ($elem->first_child('BugLocations') == 0){
		next;
	  }
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
	  	case "4" {$tag = $file_name.':'.$start_line.":".$end_line.":".$bug_code.":".$bug_msg}
		case "3" {$tag = $file_name.':'.$start_line.":".$end_line.":".$bug_code}
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
	
	}
	###################################parsing CSV as XML#################################
	
	my $twig2 = XML::Twig->new();
	$twig2->parsefile($file2);
	my $root_csv = $twig2->root;;

	my $count_csv = 0;
	my @kids_csv = $root_csv->children;
	#$root->print;
	#$kids[0]->print;
	my $start_line_csv;
	my $end_line_csv;
	
	foreach my $elem_csv (@kids_csv){
		
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
			case "4" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv.':'.$bug_code_csv.":".$bug_msg_csv}
	  		case "3" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv.':'.$bug_code_csv}
			case "2" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv}
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
	}	
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
	print $fh_out "total differences found = $total_difference\n";
	print $fh_out "total duplicates found in file1= $count_dup\n ";
	close ($fh) or die ("unable to close the xml file");
}
