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
    "weakness_count_file=s" => \$$weakness_count_file,
    "help" => \$help,
    "version" => \$version
) or die("Error");

Util::Usage() if defined ( $help );
Util::Version() if defined ( $version );

if ( !$tool_name ) {
	$tool_name = Util::GetToolName($summary_file);
}

my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser($summary_file);

my $locationId;
my $methodId;
my $sourcePathId = 0;

my %cweHash;
my %suggestionHash;
my %categoryHash;
my %sourcePathHash;

my $cwe_xpath      = 'BugCollection/BugPattern';
my $category_xpath = 'BugCollection/BugCategory';
my $source_xpath   = 'BugCollection/Project/SrcDir';
my $xpath1         = 'BugCollection/BugInstance';

my $twig1 = XML::Twig->new(
	twig_roots    => { $cwe_xpath => 1 },
	twig_handlers => { $cwe_xpath => \&parseBugPattern }
);

foreach my $input_file (@input_file_arr) {
	$twig1->parsefile("$input_dir/$input_file");
}

$twig1->purge();

my $twig2 = XML::Twig->new(
	twig_roots    => { $category_xpath => 1 },
	twig_handlers => { $category_xpath => \&parseBugCategory }
);

foreach my $input_file (@input_file_arr) {
	$twig2->parsefile("$input_dir/$input_file");
}

$twig2->purge();

my $twig3 = XML::Twig->new(
	twig_roots    => { $source_xpath => 1 },
	twig_handlers => { $source_xpath => \&parseSourcePath }
);

foreach my $input_file (@input_file_arr) {
	$twig3->parsefile("$input_dir/$input_file");
}

$twig3->purge();

my $twig4 = XML::Twig->new(
	twig_roots    => { $xpath1 => 1 },
	twig_handlers => { $xpath1 => \&parseViolations }
);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	$locationId = 0;
	$methodId   = 0;
	$twig4->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();
$twig4->purge();

if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}

sub parseViolations {
	my ( $tree, $elem ) = @_;

	my $bug_xpath = $elem->path();

	my $bugObject =
	  GetFindBugsBugObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
	$elem->purge() if defined($elem);

	$xmlWriterObj->writeBugObject($bugObject);
	$tree->purge();
}

sub GetFindBugsBugObject() {
	my $elem      = shift;
	my $bugId     = shift;
	my $bug_xpath = shift;
	my (
		$bugcode, $bugmsg,      $severity,   $category, $priority,
		$summary, $explanation, $error_line, @tokens,   $length
	);

	my $bugObject = new bugInstance($bugId);
	$bugObject->setBugReportPath(
		Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ) );
	$bugObject->setBugBuildId($build_id);
	$bugObject->setBugSeverity( $elem->att('priority') );
	$bugObject->setBugRank( $elem->att('rank') ) if defined $elem->att('rank');
	$bugObject->setBugPath( $elem->path() . "[" . $bugId . "]" )
	  if defined $elem->path();
	$bugObject->setBugGroup( $elem->att('category') );

	my $SourceLineNum = 0;
	my $classNum      = 0;
	my @children      = $elem->children;
	foreach my $itr (@children) {
		if ( $itr->gi eq 'SourceLine' ) { $SourceLineNum++; }
	}

	foreach my $itr1 (@children) {
		if ( $itr1->gi eq 'Class' ) { $classNum++; }
	}
	foreach $element ( $elem->children ) {
		my $tag = $element->gi;
		if ( $tag eq "LongMessage" ) {
			$bugObject->setBugMessage( $element->text );
		}
		elsif ( $tag eq 'SourceLine' ) {
			$bugObject = sourceLine( $element, $SourceLineNum, $bugObject );
		}
		elsif ( $tag eq 'Method' ) {
			$bugObject = bugMethod( $element, $bugObject );
		}
		elsif ( $tag eq 'Class' ) {
			$bugObject = parseClass( $element, $classNum, $bugObject );
		}
	}
	$bugObject = bugCweId( $elem->att('type'), $bugObject );
	$bugObject = bugSuggestion( $elem->att('type'), $bugObject );
	return $bugObject;
}

sub sourceLine {
	my ($elem)          = shift;
	my ($SourceLineNum) = shift;
	my $bugObject       = shift;
	my $classname       = $elem->att('classname');
	$locationId++;
	my $flag;
	my $sourceFile = $elem->att('sourcepath');
	( $sourceFile, $flag ) = &resolveSourcePath($sourceFile);
	my $startLineNo = $elem->att('start');
	my $endLineNo   = $elem->att('end');
	my $startCol    = "0";
	my $endCol      = "0";
	my $message     = $elem->first_child->text if defined( $elem->first_child );
	my $primary     = $elem->att('primary');

	if ( not defined($primary) ) {
		if   ( $SourceLineNum > 1 ) { $primary = "false"; }
		else                        { $primary = "true"; }
	}
	$bugObject->setBugLocation(
		$locationId, $classname, $sourceFile, $startLineNo, $endLineNo,
		$startCol,   $endCol,    $message,    $primary,     $flag
	);
	return $bugObject;

}

sub bugMethod {
	my ($elem)      = shift;
	my ($bugObject) = shift;
	$methodId++;
	my $classname  = $elem->att('classname');
	my $methodName = $elem->att('name');
	my $primary    = $elem->att('primary');
	$primary = "false" if not defined($primary);
	$bugObject->setBugMethod( $methodId, $classname, $methodName, $primary );
	return $bugObject;
}

sub parseClass {
	my ($elem)    = shift;
	my $classNum  = shift;
	my $bugObject = shift;
	my $classname = $elem->att('classname');
	my $primary   = $elem->att('primary');
	if ( defined($primary) && ( $primary ne 'true' ) && $classNum > 1 ) {
		return;
	}
	my $children;
	my ( $sourcefile, $start, $end, $classMessage, $resolvedFlag );
	if ( defined($primary) && $primary eq 'true' ) {
		foreach $children ( $elem->children ) {
			my $tag = $children->gi;
			if ( $tag eq "SourceLine" ) {
				$start      = $children->att('start');
				$end        = $children->att('end');
				$sourcefile = $children->att('sourcepath');
				( $sourcefile, $resolvedFlag ) = resolveSourcePath($sourcefile);
				$classMessage = $children->first_child->text
				  if defined( $children->first_child );
			}
		}
	}
	$bugObject->setClassAttribs( $classname, $sourcefile, $start, $end,
		$classMessage );
	return $bugObject;
}

sub resolveSourcePath {
	my ($path) = @_;
	my $pathId;
	my $flag = "false";
	foreach $pathId ( sort { $a <=> $b } keys(%sourcePathHash) ) {
		if ( -e "$sourcePathHash{$pathId}/$path" ) {
			$path = "$sourcePathHash{$pathId}/$path";
			$flag = "true";
			last;
		}
	}
	if ( $flag eq "true" ) {
		$path = Util::AdjustPath( $package_name, $cwd, $path );
	}

	#        print $path, "\n";
	return ( $path, $flag );
}

sub parseBugPattern {
	my ( $tree, $elem ) = @_;
	my $type  = $elem->att('type');
	my $cweid = $elem->att('cweid');
	my $suggestion;
	my $element;
	foreach $element ( $elem->children ) {
		my $tag = $element->gi;
		if ( $tag eq "Details" ) { $suggestion = $element->text; }
	}
	$cweHash{$type}        = $cweid;
	$suggestionHash{$type} = $suggestion;
	$tree->purge();
}

sub parseBugCategory {
	my ( $tree, $elem ) = @_;
	my $category = $elem->att('category');
	my $description;
	my $element;
	foreach $element ( $elem->children ) {
		my $tag = $element->gi;
		if ( $tag eq "Description" ) { $description = $element->text; }
	}
	$categoryHash{$category} = $description;
	$tree->purge();
}

sub parseSourcePath {
	my ( $tree, $elem ) = @_;
	my $sourcepath = $elem->text;
	$sourcePathHash{ ++$sourcePathId } = $sourcepath if defined($sourcepath);
	$tree->purge();
}

sub bugCweId {
	my ($type) = shift;
	my $bugObject = shift;
	if ( defined $type ) {
		my $cweId = $cweHash{$type};
		$bugObject->setCweId($cweId);
		$bugObject->setBugCode($type);
	}
	return $bugObject;
}

sub bugSuggestion {
	my $type = shift;
	my $bugObject = shift;
	if ( defined $type ) {
		my $suggestion = $suggestionHash{$type};
		$suggestion =~ s/(^ *)|( *$)//g;
		$suggestion =~ s/\n|\r/ /g;
		$bugObject->setBugSuggestion($suggestion);
	}
	return $bugObject;
}

