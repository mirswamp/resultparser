#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

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
	twig_roots         => { 'file'  => 1 },
	start_tag_handlers => { 'file'  => \&setFileName },
	twig_handlers      => { 'error' => \&parseViolations }
);

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	$twig->parsefile($input_file);
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub setFileName {
	my ( $tree, $element ) = @_;
	$file_path = $element->att('name');
	$element->purge() if defined($element);
	$file_Id++;

}

sub parseViolations {
	my ( $tree, $elem ) = @_;

	my $bug_xpath = $elem->path();

	my $bugObject =
	  getCheckstyleBugObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
	$elem->purge() if defined($elem);

	$xmlWriterObj->writeBugObject($bugObject);
}

sub getCheckstyleBugObject() {
	my $violation        = shift;
	my $adjustedFilePath = Util::AdjustPath( $package_name, $cwd, $file_path );
	my $bugId            = shift;
	my $bug_xpath        = shift;
	my $beginLine        = $violation->att('line');
	my $endLine          = $beginLine;
	my $beginColumn =
	  defined( $violation->att('column') ) ? $violation->att('column') : 0;
	my $endColumn   = $beginColumn;
	my $source_rule = $violation->att('source');
	my $priority    = $violation->att('severity');
	my $message     = $violation->att('message');
	my $bugObject   = new bugInstance($bugId);
	###################
	$bugObject->setBugLocation( 1, "", $adjustedFilePath, $beginLine, $endLine,
		$beginColumn, 0, "", 'true', 'true' );
	$bugObject->setBugMessage($message);
	$bugObject->setBugSeverity($priority);
	$bugObject->setBugGroup($priority);
	$bugObject->setBugCode($source_rule);
	$bugObject->setBugPath(
		$bug_xpath . "[" . $file_Id . "]" . "/error[" . $bugId . "]" );
	$bugObject->setBugBuildId($build_id);
	$bugObject->setBugReportPath(
		Util::AdjustPath( $package_name, $cwd, $input_file ) );
	return $bugObject;
}

