#!/usr/bin/perl -w

#use strict;
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
    "weakness_count_file=s" => \$weakness_count_file,
    "help" => \$help,
    "version" => \$version
) or die("Error");

Util::Usage() if defined ( $help );
Util::Version() if defined ( $version );

my @parsed_summary = Util::ParseSummaryFile($summary_file);
my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser(@parsed_summary);
my @build_id_arr = Util::GetBuildIds(@parsed_summary);
undef @parsed_summary;

if( !$tool_name ) {
    $tool_name = Util::GetToolName($summary_file);
}

my $twig = XML::Twig->new(
	twig_roots    => { 'issues' => 1 },
	twig_handlers => { 'issue'  => \&parseViolations }
);

my $bugId       = 0;
my $file_Id     = 0;
my $count = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

my $temp_input_file;
foreach my $input_file (@input_file_arr) {
    $temp_input_file = $input_file;
    $build_id = $build_id_arr[$count];
    $count++;
    $twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}

sub parseViolations {
    my ( $tree, $elem ) = @_;

    my $bug_xpath = $elem->path();

    my $bugObject =
	    getAndroidLintBugObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
    $elem->purge() if defined($elem);

    $xmlWriterObj->writeBugObject($bugObject);
}

sub getAndroidLintBugObject() {
    my $elem      = shift;
    my $bugId     = shift;
    my $bug_xpath = shift;
    my (
	$bugcode, $bugmsg,      $severity,   $category, $priority,
	$summary, $explanation, $error_line, @tokens,   $length, $error_line_position, $url, $urls
    );
    $bugcode     = $elem->att('id');
    $severity    = $elem->att('severity');
    $bugmsg      = $elem->att('message');
    $category    = $elem->att('category');
    $priority    = $elem->att('priority');
    $summary     = $elem->att('summary');
    $explanation = $elem->att('explanation');
    $error_line  = $elem->att('errorLine2');
    $error_line_position = $elem->att('errorLine1');
    $url = $elem->att('url');
    $urls = $elem->att('urls');
    

    if ( defined($error_line) ) {
	@tokens = split( '(\~)', $error_line );
    }
    $length = ( $#tokens + 1 ) / 2;
    my $bugObject = new bugInstance($bugId);
    ###################
    $bugObject->setBugMessage($bugmsg);
    $bugObject->setBugSeverity($severity);
    $bugObject->setBugGroup($category);
    $bugObject->setBugCode($bugcode);
    $bugObject->setBugSuggestion($summary);
    $bugObject->setBugPath( $bug_xpath . "[$bugId]" );
    $bugObject->setBugBuildId($build_id);
    $bugObject->setBugReportPath($temp_input_file);
    $bugObject->setBugPosition($error_line_position);
    $bugObject->setURLText($url." , ".$urls)  if defined ($url); 
    my $location_num = 0;

    foreach my $child_elem ( $elem->children ) {
	if ( $child_elem->gi eq "location" ) {
	    my $filepath =
	      Util::AdjustPath( $package_name, $cwd, $child_elem->att('file') );
	    my $line_num  = $child_elem->att('line');
	    my $begin_col = $child_elem->att('column');
	    my $end_col;
	    if   ( $length >= 1 ) { $end_col = $begin_col + $length; }
	    else                  { $end_col = $begin_col; }
	    $bugObject->setBugLocation(
		++$location_num, "",         $filepath, $line_num,
		$line_num,       $begin_col, $end_col,  $explanation,
		'true',          'true'
	    );
	}
	else {
	    print "found an unknown tag: " ;
	}
    }
    return $bugObject;
}

