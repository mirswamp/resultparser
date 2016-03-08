#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use util;

my (
	$input_file,   $output_file, $tool_name, $tool_version, $uuid,
	$package_name, $build_id,    $cwd,       $replace_dir,  $file_path
);
my $violationId = 0;
my $bugId       = 0;
my $file_Id     = 0;

GetOptions(
	"input_file=s"     => \$input_file,
	"output_file=s"    => \$output_file,
	"tool_name=s"      => \$tool_name,
	"tool_version=s"   => \$tool_version,
	"package_name=s"   => \$package_name,
	"uuid=s"           => \$uuid,
	"build_id=s"       => \$build_id,
	"cwd=s"            => \$cwd,
	"replace_dir=s"    => \$replace_dir,
	"input_file_arr=s" => \@input_file_arr
) or die("Error");

my $twig = XML::Twig->new(
	twig_roots    => { 'errors' => 1 },
	twig_handlers => { 'error'  => \&parseViolations }
);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	$twig->parsefile($input_file);
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub parseViolations {
	my ( $tree, $elem ) = @_;

	my $bug_xpath = $elem->path();
	my $file      = "";
	my $lineno    = "";

	my $bugObject =
	  getCppCheckBugObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
	$elem->purge() if defined($elem);

	$xmlWriterObj->writeBugObject($bugObject);
}

sub getCppCheckBugObject() {
	my $violation        = shift;
	my $adjustedFilePath = util::AdjustPath( $package_name, $cwd, $file_path );
	my $bugId            = shift;
	my $bug_xpath        = shift;
	my $bug_code         = $violation->att('id');
	my $bug_severity     = $violation->att('severity');
	my $bug_message      = $violation->att('msg');
	my $bug_message_verbose = $violation->att('verbose');

	my $bugObject  = new bugInstance($bugId);
	my $locationId = 0;

	foreach my $error_element ( $violation->children ) {
		my $tag    = $error_element->tag;
		my $file   = "";
		my $lineno = "";
		if ( $tag eq 'location' ) {
			$file =
			  util::AdjustPath( $package_name, $cwd,
				$error_element->att('file') );
			$lineno = $error_element->att('line');
			$locationId++;
			$bugObject->setBugLocation( locationId, "", $file, $lineno,
				$lineno, "0", "0", $bug_message,
				'true',  'true'
			);
		}
	}

	$bugObject->setBugMessage($bug_message_verbose);
	$bugObject->setBugGroup($bug_severity);
	$bugObject->setBugCode($bug_code);
	$bugObject->setBugPath( $bug_xpath . "[" . $bugId . "]" );
	$bugObject->setBugBuildId($build_id);
	$bugObject->setBugReportPath(
		util::AdjustPath( $package_name, $cwd, $input_file ) );
	return $bugObject;
}

