#!/usr/bin/perl -w

#use strict;
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

my @parsed_summary = Util::ParseSummaryFile($summary_file);
my ( $uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version,
	@input_file_arr )
  = Util::InitializeParser(@parsed_summary);
my @build_id_arr = Util::GetBuildIds(@parsed_summary);
undef @parsed_summary;

my $twig = XML::Twig->new(
	start_tag_handlers => { 'file'      => \&SetFileName },
	twig_handlers      => { 'violation' => \&ParseViolations }
);

#Initialize the counter values
my $bugId   = 0;
my $file_Id = 0;
my $count   = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	$build_id = $build_id_arr[$count];
	$count++;
	$twig->parsefile("$input_dir/$input_file");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub SetFileName {
	my ( $tree, $element ) = @_;
	$file_path = $element->att('name');
	$element->purge() if defined($element);
	$file_Id++;

}

sub ParseViolations {
	my ( $tree, $elem ) = @_;

	my $bug_xpath = $elem->path();

	my $bugObject =
	  GetPmdBugObject( $elem, $xmlWriterObj->getBugId(), $bug_xpath );
	$elem->purge() if defined($elem);

	$xmlWriterObj->writeBugObject($bugObject);
}

sub GetPmdBugObject() {
	my $violation        = shift;
	my $adjustedFilePath = Util::AdjustPath( $package_name, $cwd, $file_path );
	my $bugId            = shift;
	my $bug_xpath        = shift;
	my $beginLine        = $violation->att('beginline');
	my $endLine          = $violation->att('endline');
	if ( $beginLine > $endLine ) {
		my $t = $beginLine;
		$beginLine = $endLine;
		$endLine   = $t;
	}
	my $beginColumn     = $violation->att('begincolumn');
	my $endColumn       = $violation->att('endcolumn');
	my $rule            = $violation->att('rule');
	my $ruleset         = $violation->att('ruleset');
	my $class           = $violation->att('class');
	my $method          = $violation->att('method');
	my $priority        = $violation->att('priority');
	my $package         = $violation->att('package');
	my $externalInfoURL = $violation->att('externalInfoUrl');
	my $message         = $violation->text;
	$message =~ s/\n//g;
	my $loc_msg;

	if ( defined($package) && defined($class) ) {
		$class = $package . "." . $class;
	}
	my $bugObject = new bugInstance($bugId);
	###################
	$bugObject->setBugLocation(
		1,        $class,       $adjustedFilePath, $beginLine,
		$endLine, $beginColumn, $endColumn,        $loc_msg,
		'true',   'true'
	);
	$bugObject->setBugMessage($message);
	$bugObject->setBugBuildId($build_id);
	$bugObject->setClassAttribs( $class, $adjustedFilePath, $beginLine,
		$endLine, "" );
	$bugObject->setBugSeverity($priority);
	$bugObject->setBugGroup($ruleset);
	$bugObject->setBugCode($rule);
	$bugObject->setBugPath(
		$bug_xpath . "[" . $file_Id . "]" . "/violation[" . $bugId . "]" );
	$bugObject->setBugBuildId($build_id);
	$bugObject->setBugReportPath(
		Util::AdjustPath( $package_name, $cwd, "$input_dir/$input" ) );
	$bugObject->setBugMethod( 1, $class, $method, 'true' ) if defined($method);
	$bugObject->setBugPackage($package);
	$bugObject->setURLText($externalInfoURL);
	return $bugObject;
}

