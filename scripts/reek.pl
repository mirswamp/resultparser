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
	"weakness_count_file=s" => \$weakness_count_file,
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

my $file_id      = 0;
my $current_file = "";
my $count        = 0;

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

if ( $input_file_arr[0] =~ /\.json$/ ) {
    foreach my $input_file (@input_file_arr) {
	$current_file = $input_file;
	$file_id++;
	$build_id = $build_id_arr[$count];
	$count++;
	my $bugObject = ParseJsonOutput("$input_dir/$input_file");
	$xmlWriterObj->writeBugObject($bugObject);
    }
}
elsif ( $input_file_arr[0] =~ /\.xml$/ ) {
    my $twig =
	    XML::Twig->new(
		    twig_handlers => { 'checkstyle/file' => \&ParseViolations } );
    foreach my $input_file (@input_file_arr) {
	$current_file = $input_file;
	$build_id     = $build_id_arr[$count];
	$count++;
	$file_id++;
	$twig->parsefile("$input_dir/$input_file");
    }
}

$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if ( defined $weakness_count_file ) {
    Util::PrintWeaknessCountFile( $weakness_count_file,
	$xmlWriterObj->getBugId() - 1 );
}

sub parseJsonOutput {
    my ($input_file) = @_;
    my $beginLine;
    my $endLine;
    my $json_data = "";
    my $filename;
    my $json_obj = "";
    {
	open FILE, $input_file or die "open $input_file: $!";
	local $/;
	$json_data = <FILE>;
	close FILE or die "close $input_file: $!";
    }
    $json_obj = JSON->new->utf8->decode($json_data);
    foreach my $warning ( @{$json_obj} ) {
	my $bugObj = new bugInstance( $xmlWriterObj->getBugId() );

	$bugObj->setBugCode( $warning->{"smell_type"} );
	$bugObj->setBugMessage( $warning->{"message"} );
	$bugObj->setBugBuildId($build_id);
	$bugObj->setBugReportPath( $current_file );
	$bugObj->setBugPath( "[" 
		  . $file_id . "]"
		  . "/error["
		  . $xmlWriterObj->getBugId()
		  . "]" );
	$bugObj->setBugGroup( $warning->{"smell_category"} );
	my $lines      = $warning->{"lines"};
	my $start_line = @{$lines}[0];
	my $end_line;

	foreach ( @{$lines} ) {
	    $end_line = $_;
	}
	$filename =
		Util::AdjustPath( $package_name, $cwd, $warning->{"source"} );
	$bugObj->setBugLocation(
		1,         "",  $filename, $start_line,
		$end_line, "0", "0",       "",
		'true',    'true'
	);
	my $context     = $warning->{"context"};
	my $class_name  = "";
	my $method_name = "";
	if ( $context =~ m/#/ ) {
	    my @context_split = split /#/, $context;
	    if ( $context_split[0] ne "" ) {
		$class_name = $context_split[0];
		$bugObj->setClassName($class_name);
		if ( $context_split[1] ne "" ) {
		    $method_name = $context_split[1];
		    $bugObj->setBugMethod( '1', $class_name, $method_name,
			    'true' );
		}
	    }
	}
	else {
	    my @smell_type_list = (
		    'ModuleInitialize',    'UncommunicativeModuleName',
		    'IrresponsibleModule', 'TooManyInstanceVariables',
		    'TooManyMethods',      'PrimaDonnaMethod',
		    'DataClump',           'ClassVariable',
		    'RepeatedConditional'
	    );
	    foreach (@smell_type_list) {
		if ( $_ eq $warning->{'smell_type'} ) {
		    $bugObj->setClassName($context);
		    last;
		}
	    }
	    if ( $warning->{'smell_type'} eq "UncommunicativeVariableName" ) {
		if ( $context =~ /^[@]/ ) {
		    $bugObj->setClassName($context);
		}
		elsif ( $context =~ /^[A-Z]/ ) {
		    $bugObj->setClassName($context);
		}
		else {
		    $bugObj->setBugMethod( '1', "", $method_name, 'true' );
		}
	    }
	}
	$xmlWriterObj->writeBugObject($bugObj);
    }
}

sub ParseViolations {
    my ( $tree, $elem ) = @_;

    #Extract File Path#
    my $filepath = Util::AdjustPath( $package_name, $cwd, $elem->att('name') );
    my $bug_xpath = $elem->path();
    my $violation;
    foreach $violation ( $elem->children ) {
	my $beginColumn = $violation->att('column');
	my $endColumn   = $beginColumn;
	my $beginLine   = $violation->att('line');
	my $endLine     = $beginLine;
	if ( $beginLine > $endLine ) {
	    my $t = $beginLine;
	    $beginLine = $endLine;
	    $endLine   = $t;
	}
	my $message = $violation->att('message');
	$message =~ s/\n//g;
	my $severity = $violation->att('severity');
	my $rule     = $violation->att('source');

	my $bugObject = new bugInstance( $xmlWriterObj->getBugId() );
	$bugObject->setBugLocation(
		1,        "",           $filepath,  $beginLine,
		$endLine, $beginColumn, $endColumn, "",
		'true',   'true'
	);
	$bugObject->setBugMessage($message);
	$bugObject->setBugSeverity($severity);
	$bugObject->setBugCode($rule);
	$bugObject->setBugBuildId($build_id);
	$bugObject->setBugReportPath( $current_file );
	$bugObject->setBugPath( $bug_xpath . "[" 
		. $file_id . "]"
		. "/error["
		. $xmlWriterObj->getBugId()
		. "]" );
	$xmlWriterObj->writeBugObject($bugObject);
    }
}
