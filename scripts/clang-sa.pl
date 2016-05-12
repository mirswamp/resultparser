#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;
use Parser;

my (
    $input_dir,  $output_file,  $tool_name, $summary_file, $weakness_count_file, $help, $version
);

GetOptions(
    "input_dir=s"   => \$input_dir,
    "output_file=s"  => \$output_file,
    "tool_name=s"    => \$tool_name,
    "summary_file=s" => \$summary_file,
    "weakness_count_file=s" => \$weakness_count_file,
    "help" => \$help,
    "version" => \$version
) or die("Error");

Util::Usage() if defined ( $help );
Util::Version() if defined ( $version );

if( !$tool_name ) {
    $tool_name = Util::GetToolName($summary_file);
}

my @parsed_summary = Util::ParseSummaryFile($summary_file);
my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser(@parsed_summary);
my @build_id_arr = Util::GetBuildIds(@parsed_summary);
undef @parsed_summary;


my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my $temp_input_file;

my $count = 0;

foreach my $input_file (@input_file_arr) {
	$temp_input_file = $input_file;
    $build_id = $build_id_arr[$count];
    $count++;
    my $index_check_flag = 1;
    if ( !-e "$input_dir/$input_file/index.html" ) {
        $index_check_flag = 0;
    }
    opendir( DIR, "$input_dir/$input_file" );
    my @filelist =
      grep { -f "$input_dir/$input_file/$_" && $_ ne "index.html" && $_ =~ m/\.html$/ }
      readdir(DIR);

    close(DIR);
    my $file_count = scalar(@filelist);
    die
"ERROR!! Clang assessment run did not complete. index.html file is missing. \n"
      if ( $file_count > 0 and $index_check_flag eq 0 );
    foreach my $file (@filelist) {
        my $in_file1 = new IO::File("<$input_dir/$input_file/$file");
        my @lines = grep /<!--.*BUG.*-->/, <$in_file1>;
        close($in_file1);
        my $in_file2 = new IO::File("<$input_dir/$input_file/$file");
        my @column = grep /class=\"rowname\".*Location.*line/, <$in_file2>;
        close($in_file2);

        my ( $BUGFILE, $BUGDESC, $BUGTYPE, $BUGCATEGORY, $BUGLINE, $BUGCOLUMN, $BUGPATHLENGTH );
        foreach my $line (@lines) {
            if ( $line =~ m/.*BUGFILE/ ) {
                $BUGFILE =
                  Util::AdjustPath( $package_name, $cwd, bugLine($line) );
            }
            elsif ( $line =~ m/.*BUGDESC/ ) { $BUGDESC = bugLine($line); }
            elsif ( $line =~ m/.*BUGTYPE/ ) { $BUGTYPE = bugLine($line); }
            elsif ( $line =~ m/.*BUGCATEGORY/ ) {
                $BUGCATEGORY = bugLine($line);
            }
            elsif ( $line =~ m/.*BUGLINE/ ) { $BUGLINE = bugLine($line); }
            elsif ( $line =~ m/.*BUGPATHLENGTH/ ) { $BUGPATHLENGTH = bugLine($line); }
        }
        foreach my $line (@column) {
            if ( $line =~ m/.*line.*column *\d.*/ ) {
                $BUGCOLUMN = &bugColumn($line);
            }
        }
        $bugId++;
        my $bugObject = new bugInstance($bugId);
        $bugObject->setBugMessage($BUGDESC);
        $bugObject->setBugCode($BUGTYPE);
        $bugObject->setBugGroup($BUGCATEGORY);
        $bugObject->setBugLocation(
            1,   "", $BUGFILE, $BUGLINE, $BUGLINE, $BUGCOLUMN,
            "0", "", "true",   "true"
        );
        $bugObject->setBugPathLength($BUGPATHLENGTH);
        $bugObject->setBugBuildId($build_id);
        $bugObject->setBugReportPath($temp_input_file );
        $xmlWriterObj->writeBugObject($bugObject);
    }
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}

sub bugLine
{
    my ($line) = @_;
    $line =~ s/(<!--)//;
    $line =~ s/-->//;
    $line =~ s/^ *//;
    my ( $val1, $val2 ) = split /\s *\s*/, $line, 2;
    $val2 =~ s/(\n|\r)$//;
    $val2 =~ s/ *$//;
    return ($val2);
}

sub bugColumn {
    my ($line) = @_;
    $line =~ s/^.*> *line *(\d)* *, *column *//;
    $line =~ s/<.*>$//;
    $line =~ s/(\n|\r)$//;
    $line =~ s/ *$//;
    return ($line);
}
1

