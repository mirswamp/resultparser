#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my ( $input_dir, $output_file, $tool_name, $summary_file, $weakness_count_file,
	$help, $version );

GetOptions(
	"input_dir=s"           => \$input_dir,
	"output_file=s"         => \$output_file,
	"tool_name=s"           => \$tool_name,
	"summary_file=s"        => \$summary_file,
	"weakness_count_file=s" => \$$weakness_count_file,
	"help"                  => \$help,
	"version"               => \$version
) or die("Error");

Util::Usage()   if defined($help);
Util::Version() if defined($version);

if ( !$tool_name ) {
	$tool_name = Util::GetToolName($summary_file);
}

my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser($summary_file);

my $file_xpath_stdviol  = 'ResultsSession/CodingStandards/StdViols/StdViol';
my $file_xpath_dupviol  = 'ResultsSession/CodingStandards/StdViols/DupViol';
my $file_xpath_flowviol = 'ResultsSession/CodingStandards/StdViols/FlowViol';
my $location_hash_xpath = 'ResultsSession/Scope/Locations/Loc';

#Initialize the counter values
my $bugId        = 0;
my $file_Id      = 0;
my $file_path    = "";
my $stdviol_num  = 0;
my $dupviol_num  = 0;
my $flowviol_num = 0;
my $locationId   = 0;
my %location_hash;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

my $newerVersion = CompareVersion($tool_version);
my $twig;

if ( !$newerVersion ) {
	$twig = XML::Twig->new(
		twig_handlers => {
			$file_xpath_stdviol  => \&ParseViolations_stdviol,
			$file_xpath_dupviol  => \&ParseViolations_dupviol,
			$file_xpath_flowviol => \&ParseViolations_flowviol
		}
	);
}
else {
	$twig = XML::Twig->new(
		twig_roots    => { 'ResultsSession' => 1 },
		twig_handlers => {
			$location_hash_xpath => \&ParseLocationHash,
			$file_xpath_stdviol  => \&ParseViolations_StdViol,
			$file_xpath_dupviol  => \&ParseViolations_DupViol,
			$file_xpath_flowviol => \&ParseViolations_FlowViol
		}
	);
}

my $input_file;

foreach $input_file (@input_file_arr) {
	$twig->parsefile("$input_dir/$input_file");
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub ParseViolations_Stdviol {
	my ( $tree, $elem ) = @_;
	my (
		$beginLine, $endLine,   $begincol, $endcol,
		$filepath,  $bugcode,   $bugmsg,   $severity,
		$category,  $bug_xpath, $file
	);
	$stdviol_num++;
	$beginLine = $elem->att('ln');
	$endLine   = $beginLine;
	if ( !$newerVersion ) {
		$file = replacePaths( $elem->att('locFile') );
		$file =~ s/\/(.*?)\/(.*?\/)/\//;
		$file = $cwd . $file;
	}
	else {
		$file = replacePathsFromHash( $elem->att('locRef') );
	}
	$filepath  = Util::AdjustPath( $package_name, $cwd, $file );
	$bugcode   = $elem->att('rule');
	$bugmsg    = $elem->att('msg');
	$severity  = $elem->att('sev');
	$category  = $elem->att('cat');
	$bug_xpath = $elem->path();
	my $bugObject = new bugInstance( $xmlWriterObj->getBugId() );
	$bugObject->setBugLocation(
		1,   "", $filepath, $beginLine, $endLine, "0",
		"0", "", 'true',    'true'
	);
	$bugObject->setBugMessage($bugmsg);
	$bugObject->setBugSeverity($severity);
	$bugObject->setBugGroup($category);
	$bugObject->setBugCode($bugcode);
	$bugObject->setBugPath( $bug_xpath . "[$stdviol_num]" );
	$bugObject->setBugBuildId($build_id);
	$bugObject->setBugReportPath($input_file);
	$tree->purge();
	$xmlWriterObj->writeBugObject($bugObject);
}

sub ParseViolations_Dupviol {
	my ( $tree, $elem ) = @_;
	my (
		$beginLine, $endLine, $begincol, $endcol,   $filepath,
		$bugcode,   $bugmsg,  $severity, $category, $bug_xpath
	);
	$locationId = 1;
	$bugcode    = $elem->att('rule');
	$bugmsg     = $elem->att('msg');
	$severity   = $elem->att('sev');
	$category   = $elem->att('cat');
	$bug_xpath  = $elem->path();
	foreach my $child_elem ( $elem->first_child('ElDescList')->children ) {
		$dupviol_num++;
		my $bugObject = new bugInstance( $xmlWriterObj->getBugId() );
		my $file;
		if ( !$newerVersion ) {
			$file = $child_elem->att('srcRngFile');
			$file =~ s/\/(.*?)\/(.*?\/)/\//;
			$file = $cwd . $file;
		}
		else {
			$file = replacePathsFromHash( $elem->att('locRef') );
		}
		$filepath  = Util::AdjustPath( $package_name, $cwd, $file );
		$beginLine = $child_elem->att('srcRngStartln');
		$endLine   = $child_elem->att('srcRngEndLn');
		$begincol  = $child_elem->att('srcRngStartPos');
		$endcol    = $child_elem->att('srcRngEndPos');
		$bugObject->setBugMessage($bugmsg);
		$bugObject->setBugSeverity($severity);
		$bugObject->setBugGroup($category);
		$bugObject->setBugCode($bugcode);
		$bugObject->setBugPath( $bug_xpath . "[$dupviol_num]" );
		$bugObject->setBugBuildId($build_id);
		$bugObject->setBugReportPath($input_file);
		my $locnmsg = $child_elem->att('desc');
		$bugObject->setBugLocation(
			$locationId, "",        $filepath, $beginLine,
			$endLine,    $begincol, $endcol,   "",
			$locnmsg,    'false',   'true'
		);
		$xmlWriterObj->writeBugObject($bugObject);
	}
	$tree->purge();
}

sub ParseViolations_Flowviol {
	my ( $tree, $elem ) = @_;
	my (
		$beginLine, $endLine, $begincol, $endcol,   $filepath,
		$bugcode,   $bugmsg,  $severity, $category, $bug_xpath
	);
	$locationId = 1;
	$flowviol_num++;
	$beginLine = $elem->att('ln');
	$endLine   = $beginLine;
	my $file;
	if ( !$newerVersion ) {
		$file = replacePaths( $elem->att('locFile') );
		$file =~ s/\/(.*?)\/(.*?\/)/\//;
		$file = $cwd . $file;
	}
	else {
		$file = replacePathsFromHash( $elem->att('locRef') );
	}
	$filepath  = Util::AdjustPath( $package_name, $cwd, $file );
	$bugcode   = $elem->att('rule');
	$bugmsg    = $elem->att('msg');
	$severity  = $elem->att('sev');
	$bug_xpath = $elem->path();
	my $bugObject = new bugInstance( $xmlWriterObj->getBugId() );
	$bugObject->setBugLocation(
		1,   "", $filepath, $beginLine, $endLine, "0",
		"0", "", 'true',    'true'
	);
	$bugObject->setBugMessage($bugmsg);
	$bugObject->setBugSeverity($severity);
	$bugObject->setBugGroup($category);
	$bugObject->setBugCode($bugcode);
	$bugObject->setBugPath( $bug_xpath . "[$flowviol_num]" );
	$bugObject->setBugBuildId($build_id);
	$bugObject->setBugReportPath($input_file);

	foreach my $child_elem ( $elem->children ) {
		if ( $child_elem->gi eq "ElDescList" ) {
			$bugObject = ParseElDescList( $child_elem, $bugObject );
		}
	}
	$xmlWriterObj->writeBugObject($bugObject);
}

sub ParseElDescList {
	my ( $elem, $bugObject ) = @_;
	foreach my $child_elem ( $elem->children ) {
		if ( $child_elem->gi eq "ElDesc" ) {
			$bugObject = ParseElDesc( $child_elem, $bugObject );
		}
	}
	return $bugObject;

}

sub ParseElDesc {
	my $elem      = shift;
	my $bugObject = shift;
	my ( $beginLine, $endLine, $begincol, $endcol, $filepath, $locnmsg );
	$locationId++;
	$beginLine = $elem->att('ln');
	if   ( defined $elem->att('eln') ) { $endLine = $elem->att('eln'); }
	else                               { $endLine = $beginLine; }
	my $file = $elem->att('srcRngFile');
	$file =~ s/\/(.*?)\/(.*?\/)/\//;
	$file     = $cwd . $file;
	$filepath = Util::AdjustPath( $package_name, $cwd, $file );
	$locnmsg  = $elem->att('desc');

	if ( $elem->att('ElType') ne ".P" ) {
		$bugObject->setBugLocation(
			$locationId, "",  $filepath, $beginLine,
			$endLine,    "0", "0",       $locnmsg,
			'false',     'true'
		);
	}
	foreach my $child_elem ( $elem->children ) {
		if ( $child_elem->gi eq "ElDescList" ) {
			$bugObject = ParseElDescList( $child_elem, $bugObject );
		}
	}
	return $bugObject;
}

sub CompareVersion {
	my $version = shift;
	my @versionSplit = split( /\./, $version );
	if ( $versionSplit[0] >= 10 ) {
		return 1;
	}
	elsif ( $versionSplit[0] == 9 && $versionSplit[1] >= 6 ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub ParseLocationHash {
	my ( $tree, $elem ) = @_;
	my $locRef = $elem->att('locRef');
	my $uri    = $elem->att('uri');
	my $path   = "";
	if ( $uri =~ /^file:\/\/[^\/]*(.*)/ ) {
		$path = $1;
	}
	else {
		die "Bad file URI $uri.";
	}
	$location_hash{$locRef} = $path;
}

sub replacePathsFromHash {
	my $locKey = shift;
	return $location_hash{$locKey};
}

