#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IO;
use Cwd;
use XML::Twig;
use Archive::Extract;
use Archive::Tar;
use Archive::Zip;
use Archive::Zip::Tree;
use Switch;
use XML::Writer;
use bugInstance;

my ($inputDir, $package, $tool, $platform, $cwd, $packageName, $toolVersion, $uuid, $toolName, $buildId);
my $curwrkdir = getcwd;
my $bug_count = 0;
my %bughash;
my %bugassfile;
my $logfile = "log";
my ($report_path_cpp, $report_path_chst, $report_path_fb, $report_path_pmd, $bugcount_ep);
my $result = GetOptions('package=s' => \$package,
			'tool=s' => \$tool,
			'platform=s' => \$platform,
			'output=s' => \$logfile);

my ($pkg_defined, $platform_defined, $tool_defined) = 0;
if (defined $package)  {
    $pkg_defined = 1;
}

if (defined $platform)  {
    $platform_defined = 1;
}

if (defined $tool)  {
    $tool_defined = 1
}

open (my $fh1, ">", $logfile);
opendir my $dh, $curwrkdir or die "could not open the dir";

while (defined $inputDir = readdir $dh)  {
    $bug_count = 0;
    $bugcount_ep = 0;
    %bughash = ();
    %bugassfile = ();
    my @tokens = split("---", $inputDir);
    if ($#tokens != 3 | ($tokens[3] ne 'parse'))  {
	next;
    }  else  {
	if ((!($pkg_defined)|($tokens[0] eq $package))
		&& (!($platform_defined)|($tokens[1] eq $platform))
		&& (!($tool_defined)|($tokens[2] eq $tool)))  {
	    print $fh1 "#########$inputDir##############\n";
	    print "##############working on $inputDir##############\n";
	    my $run_successful = run_success($inputDir);
	    if ($run_successful == 0)  {
		print "the run $inputDir was not successfule\n";
		next;
	    }
	    my $input_path = $curwrkdir."/".$inputDir;
	    my $results_dir = $input_path."/results";
	    my $parsed_result = $input_path."/parsed_results";
	    my $asm_path = $results_dir."/assessment_summary.xml";
	    untar_results($results_dir);
	    untar($input_path, $parsed_result);
	    my @lines = `perl parseSummary.pl --summary_file = $asm_path`;
	    for (my $i = 0;$i <= $#lines; $i++)  {
		chomp($lines[$i]);
		my @tokens = split("~:~", $lines[$i]);
		my $report_path = $results_dir."/".$tokens[5]; 
		$toolName = $tokens[2];
		$toolVersion = $tokens[3];
		$buildId = $tokens[4];
		$packageName = $tokens[1];
		$cwd = $tokens[6];
		$uuid = $tokens[0];
		switch($toolName)  {
		    case "cppcheck"	{cppcheck($report_path)}
		    case "gcc-warn"	{gccwarn($report_path)}
		    case "checkstyle"	{checkstyle($report_path)}
		    case "FindBugs"	{findbugs($report_path)}
		    case "pmd"		{pmd($report_path)}
		    case "error-prone"	{errorprone($report_path)}
		    case "clang-sa"	{clang($report_path)}
		}
	    }
	    PrintXML();
	    print $fh1 "count is $bug_count\n";
	    my $count_status = status_count();
	    if ($count_status != $bug_count)  {
		print $fh1 "*******COUNTS DO NOT MATCH*****\n";
#			diff_scarf($parsed_result."/parsed_assessment_result.xml", $curwrkdir."/".$inputDir."_out.xml", $fh1, 2);
		diff_scarf($curwrkdir."/".$inputDir."_out.xml", $parsed_result."/parsed_assessment_result.xml", $fh1, 2);
	    }
	    print $fh1 "#################################\n";
	}
    }

}

$fh1->close;


sub cppcheck
{
    my $report_path = shift;
    $report_path_cpp = $report_path;
    my $file_xpath = "results/errors/error";
    my $twig = new XML::Twig(TwigHandlers => {$file_xpath => \&cpp_parseError});	
    $twig->parsefile($report_path);
    $twig->purge();
}


sub cpp_parseError
{
    my($tree, $elem) = @_;
    foreach my $error ($elem->children)
    {
	my $tag = $error->tag;
	if ($tag eq 'location')
	{
	    $bug_count++;
	    my $filePath = AdjustPath($packageName, $cwd, $error->att('file'));
	    my $lineNum = $error->att('line');
	    my $bugObj = new bugInstance($bug_count);
	    $bughash{$bug_count}=$bugObj;
	    $bughash{$bug_count}->setBugLocation(0, "", $filePath, $lineNum, $lineNum, 0,0, "", "true", "true");
	    $bugassfile{$bug_count}=$report_path_cpp;

	}
    }
}


sub clang
{
    my $dir_path = shift;
    opendir my $directory, $dir_path or die "could not open the dir";
    while (defined my $rf = readdir $directory)  {
	if ($rf =~ /^report.*.html$/)  {
	    open (my $fh_clang, "<", $dir_path."/".$rf) or die "file not found";
	    my @lines = grep /<!--.*BUG.*-->/, <$fh_clang>;
	    my ($filePath, $startLine, $endLine);
	    foreach my $line (@lines)  {
		chomp ($line);
		if ($line =~ m/.*BUGFILE/)  {
		    $bug_count++;
		    $line =~ s/(<!--)//;
		    $line =~ s/-->//;
		    $line =~ s/^\s+//;
		    $line =~ s/\s+$//;
		    my @tokens = split('\s', $line, 2);
		    $filePath = AdjustPath($packageName, $cwd, $tokens[1]);
		}

		if ($line =~ m/.*BUGLINE/)  {
		    $line =~ s/(<!--)//;
		    $line =~ s/-->//;
		    $line =~ s/^\s+//;
		    $line =~ s/\s+$//;
		    my @tokens = split('\s', $line);
		    $startLine = $tokens[1];
		    $endLine = $tokens[1];
		}

	    }
	    my $bugObj = new bugInstance($bug_count);
	    $bughash{$bug_count}=$bugObj;
	    $bughash{$bug_count}->setBugLocation(0, "", $filePath, $startLine, $endLine, 0,0, "", "true", "true");
	    $bugassfile{$bug_count}=$dir_path."/".$rf;

	}
    }
}


sub gccwarn
{
    my $report_path = shift;
    open(my $fh_op, "<", "$report_path") or die "could not find the report\n";
    while (<$fh_op>)  {
	my @tokens = split(":", $_);
	if (($#tokens == 4) && ($tokens[4] =~ /\[.*\]/))  {
	    $bug_count++;
	    my $filePath = AdjustPath($packageName, $cwd, $tokens[0]);
	    my $lineNum = $tokens[1];
	    my $bugObj = new bugInstance($bug_count);
	    $bughash{$bug_count}=$bugObj;
	    $bughash{$bug_count}->setBugLocation(0, "", $filePath, $lineNum, $lineNum, 0,0, "", "true", "true");
	    $bugassfile{$bug_count}=$report_path;
	}	

    }
}


sub checkstyle
{
    my $report_path = shift;
    $report_path_chst = $report_path;
    my $file_xpath = 'checkstyle/file';
    my $twig = new XML::Twig(TwigHandlers => {$file_xpath => \&checkstyle_parse});
    $twig->parsefile($report_path);
    $twig->purge();
}


sub checkstyle_parse
{
    my ($tree, $elem) = @_;
    my $filePath = AdjustPath($packageName, $cwd, $elem->att('name'));
    foreach my $bug ($elem->children)  {
	$bug_count++;
	my $beginLine = $bug->att('line');
	my $endLine = $beginLine;
	my $bugCode = $bug->att('source');
	my $bugObj = new bugInstance($bug_count);
	$bughash{$bug_count}=$bugObj;
	$bughash{$bug_count}->setBugLocation(0, "", $filePath, $beginLine, $endLine, 0,0, "", "true", "true");
	$bugassfile{$bug_count}=$report_path_chst;

    }
}


sub findbugs
{
    my $report_path = shift;
    $report_path_fb = $report_path;
    my $file_xpath = 'BugCollection/BugInstance';
    my $twig = new XML::Twig(TwigHandlers => {$file_xpath => \&findbugs_parse});
    $twig->parsefile($report_path);
    $twig->purge();
}


sub findbugs_parse
{
    $bug_count++;
    my($tree, $elem) = @_;
    my $bugCode = $elem->att('type');
    foreach my $element ($elem->children)  {
	my $tag = $element->gi;
	if ($tag eq "SourceLine")  {
	    my $filePath = AdjustPath($packageName, $cwd, $element->att('sourcepath'));
	    my $startLine = $element->att('start');
	    my $endLine = $element->att('end');
	    my $bugObj = new bugInstance($bug_count);
	    $bughash{$bug_count}=$bugObj;
	    $bughash{$bug_count}->setBugLocation(0, "", $filePath, $startLine, $endLine, 0,0, "", "true", "true");
	    $bugassfile{$bug_count}=$report_path_fb;

	} 
    }
}


sub pmd
{
    my ($report_path) = @_;

    $report_path_pmd = $report_path;
    my $file_xpath = 'pmd/file';
    my $twig = new XML::Twig(TwigHandlers => {$file_xpath => \&pmd_parse});
    $twig->parsefile($report_path);
    $twig->purge();
}


sub pmd_parse
{
    my ($tree, $elem) = @_;

    my $filePath = AdjustPath($packageName, $cwd, $elem->att('name'));
    foreach my $element ($elem->children)  {
	$bug_count++;
	my $startLine = $element->att('beginline');
	my $endLine    = $element->att('endline');
	my $bugCode    = $element->att('rule');
	my $bugObj = new bugInstance($bug_count);
	$bughash{$bug_count}=$bugObj;
	$bughash{$bug_count}->setBugLocation(0, "", $filePath, $startLine, $endLine, 0,0, "", "true", "true");
	$bugassfile{$bug_count}=$report_path_pmd;
    }
}


sub errorprone
{
    my ($report_path) = @_;	

    open (my $fh2, "<", "$report_path");
    my @lines;
    while (<$fh2>)  {
	push(@lines, $_);
    }

    for (my $i = 0;$i <= $#lines;$i++)  {
	my @tokens = split(":", $lines[$i]);
	if ($#tokens != 3 | !($tokens[3] =~ /^\s*\[.*\]/))  {
	    next;
	}  else  {
	    $bug_count++;
	    my $filePath = AdjustPath($packageName, $cwd, $tokens[0]);
	    my $startLine = $tokens[1];
	    my $endLine = $startLine;
	    $tokens[3] =~ /^\s*\[(.*)\].*$/;
	    my $bugCode = $1; 
	    my $bugObj = new bugInstance($bug_count);
	    $bughash{$bug_count}=$bugObj;
	    $bughash{$bug_count}->setBugLocation(0, "", $filePath, $startLine, $endLine, 0,0, "", "true", "true");
	    $bughash{$bug_count}->setBugCode($bugCode);
	    $bugassfile{$bug_count}=$report_path; 
	}
    }

    if ((($lines[$#lines]) =~ /error/) | ($lines[$#lines] =~ /warn/))  {
	my @tokens = split("\s", $lines[$#lines]);
	$bugcount_ep = $bugcount_ep+$tokens[0];
    } 

    if ((($lines[$#lines-1]) =~ /error/) | ($lines[$#lines-1] =~ /warn/))  {
	my @tokens = split("\s", $lines[$#lines-1]);
	$bugcount_ep = $bugcount_ep+$tokens[0];
    } 

    return;
}


sub NormalizePath
{
    my $p = shift;

    $p =~ s/\/\/+/\//g;			# collapse consecutive /'s to one /
    $p =~ s/\/(\.\/)+/\//g;		# change /./'s to one /
    $p =~ s/^\.\///;			# remove initial ./
    $p = '.' if $p eq '';		# change empty dirs to .
    $p =~ s/\/\.$/\//;			# remove trailing . directory names
    $p =~ s/\/$// unless $p eq '/';	# remove trailing /

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


sub status_count
{
    my $status_out_path =  $curwrkdir."/".$inputDir."/status.out";

    open(my $fh, "<", "$status_out_path") or die "status.out not found";
    while (<$fh>)  {
	if ($_ =~ /\(weaknesses: (.*)\)/)  {
	    print $fh1 "count in status.out is $1\n";
	    return $1;
	    last;
	}
    }
}


sub run_success
{
    my $name = shift;
    my $status_path = $curwrkdir."/".$name."/status.out";
    open (my $fh, "<", $status_path) or return 0;
    while (<$fh>)  {
	if ($_ =~ /PASS: all/)  {
	    return 1;
	}
    }
    $fh->close;
    return 0;
}


sub untar_results
{
    my $path =	$curwrkdir."/".$inputDir;
    my $result_path = $path."/results";
    if (!(-d $result_path))
    {
	print "untarring the results directory\n";
	my $ae = Archive::Extract->new(archive=> $result_path.".tar.gz");
	$ae->extract(to => $path);
    }
}


sub untar
{
    my $output_dir = shift;
    my $output = shift;
    if (!(-d $output))  {
	print "untarring the parsed_result directory\n";
	my $ae = Archive::Extract->new(archive=> $output.".tar.gz");
	$ae->extract(to => $output_dir);		
    }
}


sub PrintXML
{
    my $outputFile = $inputDir."_out.xml";
    open(my $oh, ">", $outputFile);
    my $writer = new XML::Writer(OUTPUT => $oh, DATA_MODE => 'true', DATA_INDENT => 2);
    $writer->xmlDecl('UTF-8');
    $writer->startTag('AnalyzerReport', 'tool_name' => "$toolName", 'tool_version' => "$toolVersion", 'uuid'=> "$uuid");
    foreach my $object (sort{$a <=> $b} keys %bughash)  {
	$bughash{$object}->printXML($writer, $bugassfile{$object}, $buildId);
    }
    $writer->endTag();
    $writer->end();
    $oh->close();
}


#####################################################################################################

# diff script########################################################################################
sub diff_scarf
{
    my $file1 = shift;
    my $file2 = shift;
    my $fh_out = shift;
    my $tag_elem = shift;
    print "$file1 and $file2\n";
    open(my $fh, "<", $file2) or die ("file not found");

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
    my $startLine;
    my $endLine;
    foreach my $elem (@kids)  {
	next if ($elem->first_child('BugLocations') == 0);

	my $filename = $elem->first_child('BugLocations')->first_child('Location')->first_child('SourceFile')->field;
	$filename = lc($filename);
	$filename =~ s/(.*?)\///;
	if ($elem->first_child('BugLocations')->first_child('Location')->first_child('StartLine') != 0)  {
	    $startLine = $elem->first_child('BugLocations')->first_child('Location')->first_child('StartLine')->field;
	}  else  {
	    $startLine = 'NA';
	}

	if ($elem->first_child('BugLocations')->first_child('Location')->first_child('EndLine') != 0)  {
	    $endLine = $elem->first_child('BugLocations')->first_child('Location')->first_child('EndLine')->field;
	}  else  {
	     $endLine = 'NA';
	}
	my $bugCode;
	if ($elem->first_child('BugCode') != 0)  {
	    $bugCode = $elem->first_child('BugCode')->field;
	    $bugCode = lc($bugCode);
	}
	my $location = $elem->first_child('BugLocations')->first_child('Location')->{'att'}->{primary};
	my $bugId  = $elem->{'att'}->{id};
	my $bugMsg;
	if ($elem->first_child('BugMessage') != 0)  {
	    $bugMsg = $elem->first_child('BugMessage')->field;
	    $bugMsg =~ s/"//g; 
	    $bugMsg = lc ($bugMsg);
	    $bugMsg =~ s/\s+$//;
	}
	my $tag;
	switch ($tag_elem)  {
	    case "4" {$tag = $filename.':'.$startLine.":".$endLine.":".$bugCode.":".$bugMsg}
	    case "3" {$tag = $filename.':'.$startLine.":".$endLine.":".$bugCode}
	    case "2" {$tag = $filename.':'.$startLine.":".$endLine}
	    case "1" {$tag = $filename}
	}

	if (!exists($hash_xml{$tag}))  {
	     $hash_xml{$tag} = {'count' => 1, 'bugid' => $bugId, 'startline' => $startLine, 'endline' => $endLine, 'location' => $location};
	     $count_xml++;
	}  else  {
	     $hash_xml{$tag}->{count} = $hash_xml{$tag}->{count}+1;
	     $hash_xml{$tag}->{bugid} = $hash_xml{$tag}->{bugid}."\n\t".$bugId;
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

    foreach my $elem_csv (@kids_csv)  {
	next if ($elem_csv->first_child('BugLocations') == 0);

	my $file_name_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('SourceFile')->field;
	$file_name_csv = lc($file_name_csv);
	$file_name_csv =~ s/(.*?)\///;
	if ($elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartLine') != 0)  {
	    $start_line_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartLine')->field;
	}  else  {
	    $start_line_csv = 'NA';
	}
	if ($elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndLine') != 0)  {
	    $end_line_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndLine')->field;
	}  else  {
	    $end_line_csv = 'NA';
	}
	my $bug_code_csv;
	if ($elem_csv->first_child('BugCode') != 0)  {
	    $bug_code_csv = $elem_csv->first_child('BugCode')->field;
	    $bug_code_csv = lc($bug_code_csv);
	}
	my $location_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->{'att'}->{primary};
	my $bug_id_csv	= $elem_csv->{'att'}->{id};
	my $bug_msg_csv;
	if ($bug_msg_csv = $elem_csv->first_child('BugMessage') != 0)  {
	    $bug_msg_csv = $elem_csv->first_child('BugMessage')->field;
	    $bug_msg_csv =~ s/"//g; 
	    $bug_msg_csv = lc ($bug_msg_csv);
	    $bug_msg_csv =~ s/\s+$//;
	}
	my $tag_csv;
	switch ($tag_elem)  {
	    case "4" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv.':'.$bug_code_csv.":".$bug_msg_csv}
	    case "3" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv.':'.$bug_code_csv}
	    case "2" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv}
	    case "1" {$tag_csv = $file_name_csv}
	}
	if ($hash_csv{$tag_csv} == 0)  {
	     $hash_csv{$tag_csv} = {'count' => 1, 'bugid' => $bug_id_csv, 'startline' => $start_line_csv, 'endline' => $end_line_csv, 'location' => $location_csv};
	     $count_csv++;
	}  else  {
	     $hash_csv{$tag_csv}->{count} = $hash_csv{$tag_csv}->{count}+1;
	     $hash_csv{$tag_csv}->{bugid} = $hash_csv{$tag_csv}->{bugid}.", ".$bug_id_csv;
	}
    }	
    my $serial_number = 1;
    my $total_difference = 0;
    print $fh_out "Sno\tfile1_bug_num\tfile1_instances\tstart_line\tend_line\tfile2_bug_num\tfile2_instances\n";
    my $elem_xml;
    my $elem_csv2;
    my $count_cmp = 0;
    foreach my $elem_xml (keys %hash_xml)  {
	$count_cmp++;
	$elem_csv2 = $elem_xml;
	if (($hash_csv{$elem_csv2} == 0))  {
	    print $fh_out "$serial_number\.)\t$hash_xml{$elem_xml}->{bugid}\t\t$hash_xml{$elem_xml}->{count}\t\t$hash_xml{$elem_xml}->{startline}\t\t$hash_xml{$elem_xml}->{endline}\t\tNA\t\tNA\t\t$hash_xml{$elem_xml}->{location}\n";
	    $serial_number++;
	    $total_difference = $total_difference+$hash_xml{$elem_xml}->{count}; 
	}  else  {
	    if (($hash_csv{$elem_csv2}->{count} != $hash_xml{$elem_xml}->{count}))  {
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
