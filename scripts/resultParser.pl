#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use Cwd qw();
use File::Basename;
use XML::Twig;
use IO qw(File);
use XML::Writer;
use Memory::Usage;

my $current_dir = Cwd::cwd();
my $script_dir = dirname(Cwd::abs_path($0 ) ) ;
my ($summary_file,$in_dir,$out_dir,$output_file,$help,$version,$logfile,$weakness_count_file,$report_summary_file, $merge );

my $mu = Memory::Usage->new();
$mu->record('Before XML Parsing');

&buildParserHash(\%parsers,"$script_dir/parsers.txt" );

GetOptions(
           "summary_file=s" => \$summary_file, 
           "input_dir=s" => \$in_dir,
           "output_dir=s" => \$out_dir,
           "output_file=s" => \$output_file,
           "help" => \$help,
           "version" => \$version,
           "merge!" => \$merge,
           "log_file=s" => \$logfile,
           "weakness_count_file=s" => \$weakness_count_file,
           "report_summary_file=s" => \$report_summary_file
          ) or &usage() and die ("Error parsing command line arguments\n" );

&usage() if defined ($help );
&version() if defined ($version );

$out_dir = defined ($out_dir ) ? $out_dir : $current_dir;
$summary_file = defined ($summary_file) ? $summary_file : "$current_dir/assessment_summary.xml";
$in_dir = defined ($in_dir) ? $in_dir : $current_dir;
$output_file = defined ($output_file ) ? ((&isAbsolutePath($output_file ) eq 0 ) ? "$out_dir/$output_file":"$output_file" ) : "$out_dir/parsed_assessment_report.xml";

if ( defined ($weakness_count_file ) ) {
    $weakness_count_file = (&isAbsolutePath($weakness_count_file ) eq 0 ) ? "$out_dir/$weakness_count_file" : "$weakness_count_file";
    ##Test Path##
    &testPath($weakness_count_file ,"W" );
    ############
} else {
    print "\nNo weakness count file, proceeding without the file\n";
}

if(defined($report_summary_file)) {
    $report_summary_file = (&isAbsolutePath($report_summary_file ) eq 0) ? "$out_dir/$report_summary_file" : "$report_summary_file";
    &testPath($report_summary_file ,"W" );
}

print "SCRIPT_DIR: $script_dir\n";
print "CURRENT_DIR: $current_dir\n";
print "SUMMARY_FILE: $summary_file\n";
print "INPUT_DIR: $in_dir\n";
print "OUTPUT_DIR: $out_dir\n";
print "OUTPUT_FILE: $output_file\n";



my $output_dir = $out_dir;
my ($global_uuid ,$global_tool_name ,$global_tool_version );
my @parsed_summary = parseSummary($summary_file );
my %bugInstanceHash;
my %byteCountHash;
my %count_hash;
my $bugId = 0;
my ($uuid ,$package_name ,$tool_name ,$tool_version ,$build_artifact_id ,$input ,$cwd, $replace_dir );
my @input_file_arr;


my $print_flag = 1;
foreach my $line (@parsed_summary )
{
    chomp($line );
    ($uuid ,$package_name ,$tool_name ,$tool_version ,$build_artifact_id ,$input ,$cwd, $replace_dir ) = split('~:~' ,$line );
    if($print_flag==1){
    	print "--------------------------------------------------------------------------------------\n";
		print "UUID: $uuid\n";
		print "PACKAGE_NAME: $package_name\n";
		print "TOOL_NAME: $tool_name\n";
		print "TOOL_VERSION: $tool_version\n";
		print "BUILD_ARTIFACT_ID: $build_artifact_id\n";
		print "REPLACE_DIR: $replace_dir\n";
		print "CWD: $cwd\n"; 
		print "INPUT_FILES:";
		$print_flag = 0;
    }
    print " ".$input;
    push @input_file_arr, "$input";
}
print "\n";
executeParser($uuid ,$package_name ,$tool_name ,$tool_version ,$build_artifact_id ,$input ,$cwd, $replace_dir, $input);
$mu->record('After XML parsing');
$mu->dump();

if (defined $weakness_count_file)
{
    open my $wkfh,">",$weakness_count_file;
    print $wkfh "weaknesses : ". scalar(keys %bugInstanceHash) . "\n";
    $wkfh->close();
}


sub executeParser
{
    my ($uuid,$package_name,$tool_name,$tool_version,$build_artifact_id,$input,$cwd,$replace_dir) = @_;
    my @execString = ("perl", $parsers{uc $tool_name}.".pl", "--input_file=$in_dir/$input","--output_file=$output_file","--tool_name=$tool_name","--tool_version=$tool_version","--package_name=$package_name","--uuid=$uuid","--build_id=$build_artifact_id","--cwd=$cwd","--replace_dir=$replace_dir");
    foreach my $input_file_name (@input_file_arr){
        push @execString, "--input_file_arr=$in_dir/$input_file_name";
    }
    my $out = system(@execString);

}

sub parseSummary
{
        my $summary_file = shift;
        my $twig = XML::Twig->new();
        $twig->parsefile($summary_file);
        my @parsed_summary;

        my $root=$twig->root;
        my @uuids = $twig->get_xpath('/assessment-summary/assessment-summary-uuid');
        my $uuid = $uuids[0]->text;
        
        my @pkg_dirs = $twig->get_xpath('/assessment-summary/package-root-dir');
        my $package_name = $pkg_dirs[0]->text;
        $package_name =~ s/\/[^\/]*$//;

        my @tool_names = $twig->get_xpath('/assessment-summary/tool-type');
        my $tool_name = $tool_names[0]->text;

        my @tool_versions = $twig->get_xpath('/assessment-summary/tool-version');
        my $tool_version = $tool_versions[0]->text;
        $tool_version =~ s/\n/ /g;

        my @assessment_root_dir =  $twig->get_xpath('/assessment-summary/assessment-root-dir');
        my $size =  @assessment_root_dir;
        if ($size > 0)
        {
            $package_name = $assessment_root_dir[0]->text;
        } 
        my @assessments = $twig->get_xpath('/assessment-summary/assessment-artifacts/assessment');
        

        foreach my $i (@assessments)
        {
            my @report=$i->get_xpath('report');
            my @target = $i->get_xpath('replace-path/target') if (defined $i->get_xpath('replace-path/target'));
            my @srcdir = $i->get_xpath('replace-path/srcdir') if (defined $i->get_xpath('replace-path/srcdir'));
            my $srcdir_path = " ";
            if (@srcdir)
            {
                $srcdir_path = $target[0]->text;    
                foreach my $elem (@srcdir)
                {
                    $srcdir_path = $srcdir_path."::".$elem->text;
                }
            }
            my @build_art_id = $i->get_xpath('build-artifact-id');
            my $build_artifact_id = 0;
            my @cwd=$i->get_xpath('command/cwd');   
            $build_artifact_id = $build_art_id[0]->text if defined ($build_art_id[0]);
            push(@parsed_summary, join("~:~",$uuid,$package_name,$tool_name,$tool_version,$build_artifact_id,$report[0]->text,$cwd[0]->text,$srcdir_path)) if defined($report[0]);
        }
        
        return @parsed_summary;
}

#############################################################################################################################################################################################################################################
sub isAbsolutePath
{
    my($path) = @_;
    if($path =~ m/^\/.*/g){
        return 1;
    }
    return 0;
}

sub testPath
{
    my($path,$mode ) = @_;
    my $fh;
    if($mode eq "W" ) {
        open $fh ,">>" ,$path or die "Cannot open file $path !!";
    }
    elsif($mode eq "R" ) {
        open $fh ,"<" ,$path or die "Cannot open file $path !!";
    }
    close ($fh);
}

sub version
{
    system ("cat $script_dir/version.txt" );
#   print "Result Parser 0.9.4\n";
    exit 0;
}

sub buildParserHash
{
    my ($hash,$file )=@_;
    open (IN,"<$file" ) or die ("Failed to open $file for reading" ) ;
    for my $line (<IN> )
    {
        chomp($line );
        my ($tool,$parser_function ) = split /#/ ,$line ,2;
        $hash->{$tool} = $parser_function;
    }
close (IN );
}


sub usage
{
print "Usage: resultParser.pl [-h] [-v]
              [--summary_file=<PATH_TO_SUMMARY_FILE>]
              [--input_dir=<PATH_TO_RESULTS_DIR>]
          [--output_dir=<PATH_TO_OUTPUT_DIR>]
          [--output_file=<OUTPUT_FILENAME>]
          [--weakness_count_file=<WEAKNESS_COUNT_FILENAME>]
          [--merge/nomerge]
          [--log_file=<LOGFILE>]
          [--report_summary_file=<REPORT_SUMMARY_FILE>]

Arguments
    -h, --help                          show this help message and exit
    -v, --version                       show the version number
    --summary_file=[SUMMARY_FILE]                   Path to the Assessment Summary File
    --input_dir=[INPUT_DIR]                         Path to the raw assessment result directory
    --output_dir=[OUTPUT_DIR]                       Path to the output directory
    --output_file=[OUTPUT_FILE]                     Output File name in merged case 
                            (relative to the output_dir)
    --merge                     Merges the parsed result in a single file (Default option)
    --nomerge                                       Do not merge the parsed results
    --weakness_count_file                           Name of the weakness count file
                            (relative to the output_dir)
    --log_file                                      Name of the log file
    exit 0;"
}

