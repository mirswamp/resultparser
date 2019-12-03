#!/usr/bin/perl -w

package Parser;

use strict;
use Getopt::Long;
use SwampUtils;
# use Util;
use XML::Twig;
use FindBin;
use Cwd;
use ScarfXmlWriter;
use SarifJsonWriter;
use MultiobjectDispatcher;
use BugInstance;

my $bashNonMetaChars = qr/[a-zA-Z0-9.,_=+\/\@:-]/;

sub GetElemText
{
    my ($e) = @_;

    if (!$e->contains_only_text())  {
	my $xpath = $e->xpath();
	die "Element $xpath must only contain text";
    }

    return $e->text();
}


sub ParseSummaryFile {
    my ($summaryFile) = @_;

    my %s = (		# parsed summary data
	# assessUuid	=> undef,
	# buildRootDir	=> undef,
	# packageRootDir=> undef,
	# toolType	=> undef,
	# toolVersion	=> undef,
	assessments	=> [],
	);
    my $curAssess = {};	# in-progress parsing of assessment
			# keys: buildId, report, cwd
			#	replacePathTarget, replacePathSrcDir,
			#	pathPrefixAdjustFrom, pathPrefixAdjustTo

    my $as = "/assessment-summary";
    my $assess = "$as/assessment-artifacts/assessment";

    my $twig = XML::Twig->new(
	twig_handlers => {
	    "$as/assessment-summary-uuid"	=> sub {
		my ($twig, $e) = @_;
		$s{uuid} = GetElemText($e);
		return 1;
	    },
	    "$as/build-root-dir"		=> sub {
		my ($twig, $e) = @_;
		$s{build_root_dir} = GetElemText($e);
		return 1;
	    },
	    "$as/package-root-dir"		=> sub {
		my ($twig, $e) = @_;
		$s{package_root_dir} = GetElemText($e);
		return 1;
	    },
	    "$as/package-name"			=> sub {
		my ($twig, $e) = @_;
		$s{package_name} = GetElemText($e);
		return 1;
	    },
	    "$as/package-version"		=> sub {
		my ($twig, $e) = @_;
		$s{package_version} = GetElemText($e);
		return 1;
	    },
	    "$as/platform-name"			=> sub {
		my ($twig, $e) = @_;
		$s{platform_name} = GetElemText($e);
		return 1;
	    },
	    "$as/platform-uuid"			=> sub {
		my ($twig, $e) = @_;
		$s{platformUuid} = GetElemText($e);
		return 1;
	    },
	    "$as/tool-type"			=> sub {
		my ($twig, $e) = @_;
		$s{tool_name} = GetElemText($e);
		return 1;
	    },
	    "$as/tool-version"			=> sub {
		my ($twig, $e) = @_;
		$s{tool_version} = GetElemText($e);
		return 1;
	    },
	    "$as/start-ts"			=> sub {
		my ($twig, $e) = @_;
		$s{assessment_start_ts} = GetElemText($e);
		return 1;
	    },
	    "$as/stop-ts"			=> sub {
		my ($twig, $e) = @_;
		$s{assessment_stop_ts} = GetElemText($e);
		return 1;
	    },
	    "$as/build-fw"			=> sub {
		my ($twig, $e) = @_;
		$s{build_fw} = GetElemText($e);
		return 1;
	    },
	    "$as/build-fw-version"		=> sub {
		my ($twig, $e) = @_;
		$s{build_fw_version} = GetElemText($e);
		return 1;
	    },
	    "$as/assess-fw"			=> sub {
		my ($twig, $e) = @_;
		$s{assess_fw} = GetElemText($e);
		return 1;
	    },
	    "$as/assess-fw-version"		=> sub {
		my ($twig, $e) = @_;
		$s{assess_fw_version} = GetElemText($e);
		return 1;
	    },
	    "$assess"				=> sub {
		my ($twig, $e) = @_;
		$curAssess->{commandLine} = BashQuoteArgList($curAssess->{args});
		push @{$s{assessments}}, $curAssess;
		$twig->purge();
		$curAssess = {};
		return 1;
	    },
	    "$assess/build-artifact-id"		=> sub {
		my ($twig, $e) = @_;
		$curAssess->{"build-artifact-id"} = GetElemText($e);
		return 1;
	    },
	    "$assess/report"			=> sub {
		my ($twig, $e) = @_;
		$curAssess->{report} = GetElemText($e);
		return 1;
	    },
	    "$assess/command/args/arg"		=> sub {
		my ($twig, $e) = @_;
		push @{$curAssess->{args}}, GetElemText($e);
	    },
	    "$assess/command/cwd"		=> sub {
		my ($twig, $e) = @_;
		$curAssess->{workingDirectory} = GetElemText($e);
		return 1;
	    },
	    "$assess/command/environment/env"	=> sub {
		my ($twig, $e) = @_;
		my $string = GetElemText($e);
		if ($string =~ /(.+?)=(.*)/) {
		    if (exists $curAssess->{env}{$1}) {
			print STDERR "env $1 already exists changing value from ($curAssess->{env}{$1}) to ($2)\n";
		    }
		    $curAssess->{env}{$1} = $2;
		}
		else {
		    print STDERR "Error parsing env:  $string\n";
		}
	    },
	    "$assess/exit-code"			=> sub {
		my ($twig, $e) = @_;
		$curAssess->{exitCode} = GetElemText($e);
		return 1;
	    },
	    "$assess/execution-successful"	=> sub {
		my ($twig, $e) = @_;
		$curAssess->{executionSuccessful} = Util::StringToBool(GetElemText($e));
		return 1;
	    },
	    "$assess/start-ts"			=> sub {
		my ($twig, $e) = @_;
		$curAssess->{startTime} = GetElemText($e);
		return 1;
	    },
	    "$assess/stop-ts"			=> sub {
		my ($twig, $e) = @_;
		$curAssess->{endTime} = GetElemText($e);
		return 1;
	    },
	    # FIXME: There is no need for the following block since it should be stop-ts
	    "$assess/end-ts"			=> sub {
		my ($twig, $e) = @_;
		$curAssess->{endTime} = GetElemText($e);
		return 1;
	    },
	    "$assess/replace-path"		=> sub {
		my ($twig, $e) = @_;
		# check for both target and srcdir
		return 1;
	    },
	    "$assess/replace-path/target"	=> sub {
		my ($twig, $e) = @_;
		$curAssess->{replacePathTarget} = GetElemText($e);
		return 1;
	    },
	    "$assess/replace-path/srcdir"	=> sub {
		my ($twig, $e) = @_;
		$curAssess->{replacePathSrcDir} = GetElemText($e);
		return 1;
	    },
	    "$assess/path-prefix-adjust"	=> sub {
		my ($twig, $e) = @_;
		# check for both from and to
		return 1;
	    },
	    "$assess/path-prefix-adjust/from"	=> sub {
		my ($twig, $e) = @_;
		$curAssess->{pathPrefixAdjustFrom} = GetElemText($e);
		return 1;
	    },
	    "$assess/path-prefix-adjust/to"	=> sub {
		my ($twig, $e) = @_;
		$curAssess->{pathPrefixAdjustTo} = GetElemText($e);
		return 1;
	    },
	},
    );

    $twig->parsefile($summaryFile);

    my @required = qw/uuid build_root_dir package_root_dir tool_name tool_version/;
    my @missing;
    foreach my $k (@required)  {
	push @missing, $k unless defined $s{$k};
    }
    die "assessment-summary xml file missing required elements: @missing"
	if @missing;

    return \%s;
}


sub GetToolName
{
    my $assessment_summary_file = shift;
    my $toolName;
    my $twig = XML::Twig->new(
	twig_roots    => {'assessment-summary' => 1},
	twig_handlers => {
	    'assessment-summary/tool-type' => sub {
		my ($tree, $elem) = @_;
		$toolName = $elem->text;
		$tree->finish_now();
	    }
	}
    );
    $twig->parsefile($assessment_summary_file);
    if (!defined $toolName)  {
	die("Error: Could not extract tool name from the summary file ");
    }
    return $toolName;
}


sub PrintWeaknessCountFile
{
    my ($fn, $weaknessCount, $status, $longMsg) = @_;

    die "PrintWeaknessCountFile: neither weaknessCount nor status defined"
    unless defined $weaknessCount || defined $status;

    if (defined $fn)  {
	open WFILE, ">", $fn or die "open $fn: $!";
	print WFILE "weaknesses: $weaknessCount\n";
	if (defined $status)  {
	    die "unknown status type '$status'"
	    unless $status =~ /^(PASS|FAIL|SKIP|NOTE)$/;
	    print WFILE "$status\n";
	}
	if (defined $longMsg && $longMsg !~ /^\s*$/)  {
	    $longMsg =~ s/\n*$//;
	    print WFILE "-----\n$longMsg\n";
	}
	close WFILE or die "close $fn: $!";
    }
}


sub CreateParsedResultsDataFile
{
    my ($fn, $extraAttrs) = @_;
    return unless defined $fn;

    my %h;
    while (my ($k, $v) = each %$extraAttrs)  {
	$h{$k} = $v if defined $v;
    }

    SwampUtils::WriteConfFile($fn, \%h);
}


sub PrintVersion
{
    my ($options) = @_;

    my $version = $options->{parserFwVersion};
    print "$version\n";
}


sub PrintUsage
{
    my ($options) = @_;

    my $prog = $options->{parserBin};

    print <<EOF;
Usage: $prog [options]...

Options:
    --input_dir=<PATH>				directory containing results
    --summary_file=<PATH>			path to assessment_summary.xml
    --output_file=<PATH>			path to scarf file
    --weakness_count_file=<PATH>		path to weakness count file
    --services_conf=<PATH>			path to services.conf file
    --parsed_results_data_conf=<PATH>		path to ressult parser data file to create
    --output_format=<scarf|sarif|scarf,sarif>	output files type(s)
    --scarf_output_file=<PATH>			path to SCARF output file
    --sarif_output_file=<PATH>			path to main SARIF output file
    --help	  -v				print this message and exit
    --version	  -h				print the version number
EOF
}


sub WriterOptionToGetOptString	{
    my ($name, $attrs) = @_;
    my %typeToSpecifier = ( b => '!', s => '=s', i => '=i', f => '=f' );
    my $type = $attrs->{type};
    die "WriterOption '$name' does not have type attribute" unless defined $type;
    $type =~ s/[@]$//;
    die "WriterOption '$name' has an unknown type attribute value '$type'"
	    unless exists $typeToSpecifier{$type};
    my $specifier = $typeToSpecifier{$type};
    my $altName = $name;
    $altName =~ s/_/-/g;
    $name .= "|$altName" unless $name eq $altName;
    $name .= $specifier;
    return $name;
}


sub ProcessOptions
{
    my %opts = @_;

    my $resultParserDefaultsConf = "$FindBin::Bin/resultParserDefaults.conf";
    $resultParserDefaultsConf = undef unless -f $resultParserDefaultsConf;
    my $parserProgName = $0;
    $parserProgName =~ s/^.*\///;

    my $resultParserDefaults = {};
    if (defined $resultParserDefaultsConf)  {
	$resultParserDefaults = SwampUtils::ReadConfFile($resultParserDefaultsConf);
    }

    my %options = (
	    input_dir			=> '.',
	    summary_file		=> undef,
	    output_file			=> undef,
	    tool_name			=> undef,
	    weakness_count_file		=> undef,
	    help			=> undef,
	    version			=> undef,

	    services_conf		=> undef,
	    parsed_results_data_conf	=> undef,

	    result_parser_defaults_conf	=> $resultParserDefaultsConf,

	    parserBin			=> $parserProgName,
	    parserFw			=> 'resultparser',
	    parserFwVersion		=> 'unknown',

	    output_format		=> 'scarf sarif',
	    scarf_output_file		=> undef,
	    sarif_output_file		=> undef,
	    %$resultParserDefaults,
	    );

    my @options = (
	    "input_dir|input-dir=s",
	    "output_file|output-file=s",
	    "tool_name|tool-name=s",
	    "summary_file|summary-file=s",
	    "weakness_count_file|weakness-count-file=s",
	    "services_conf|services-conf=s",
	    "result_parser_defaults_conf|result-parser-defaults-conf=s",
	    "output_format|output-format=s",
	    "scarf_output_file|scarf-output-file=s",
	    "sarif_output_file|sarif-output-file=s",
	    "help|h!",
	    "version|v!",
	    );

    my @externalizable = [
	"addresses",
	"artifacts",
	"graphs",
	"invocations",
	"logicalLocations",
	"policies",
	"webRequests",
	"webResponses",
	"results",
	"taxonomies",
	"threadFlowLocations",
	"translations",
    ];
    my %writerOptionsData = (
	    pretty			=> {type => 'b', default => 1},
	    error_level			=> {type => 'i', default => 0,	validValues => [0, 1, 2]},
	    addArtifacts		=> {type => 'b'},
	    addArtifactsNoLocation	=> {type => 'b', default => 1},
	    addProvenance		=> {type => 'b', default => 1},
	    artifactHashes		=> {type => 'b'},
	    sortKeys			=> {type => 'b'},
	    addSnippets			=> {type => 'b'},
	    extraSnippets		=> {type => 'i'},
	    externalized		=> {type => 's@', default => '', validValues => \@externalizable},
    );

    foreach my $name (keys %writerOptionsData)	{
	my $attrs = $writerOptionsData{$name};
	push @options, WriterOptionToGetOptString($name, $attrs);
	my $default;
	if (exists $attrs->{default})  {
	    $default = $attrs->{default};
	}  elsif ($attrs->{type} = 'b')  {
	    $default = 0;
	}  elsif ($attrs->{type} = 's')  {
	    $default = '';
	}
	$options{$name} = $default;
    }

    Getopt::Long::Configure(qw/require_order no_ignore_case no_auto_abbrev/);
    my $ok = GetOptions(\%options, @options);

    if (defined $options{services_conf})  {
	my $servicesConf = SwampUtils::ReadConfFile($options{services_conf});
	foreach my $name (keys %writerOptionsData)  {
	    my $servicesName = "resultparser-$name";
	    $options{$name} = $servicesConf->{$servicesName} if exists $servicesConf->{$servicesName};
	}
    }

    my @errs;

    for my $opt (qw/summary_file output_file/)	{
	if (!defined $options{$opt})  {
	    $ok = 0;
	    push @errs, "Error: --$opt must be specified";
	}
    }

    my $outputFile = $options{output_file};
    $options{scarf_output_file} = $outputFile unless defined $options{scarf_output_file};
    if (!defined $options{sarif_output_file})  {
	my $sarifOutputFile = $options{scarf_output_file};
	if ($sarifOutputFile =~ s/\.xml$/.sarif.json/)	{
	    $options{sarif_output_file} = $sarifOutputFile;
	}
    }

    my $outputFormat = $options{output_format};
    $options{sarif_output_file} = undef unless $outputFormat =~ /\bsarif\b/i;
    $options{scarf_output_file} = undef unless $outputFormat =~ /\bscarf\b/i;

    push @errs, "ERROR: want SCARF output, but no output file specified" if $outputFormat =~ /\bscarf\b/ && !defined $options{scarf_output_file};
    push @errs, "ERROR: want SARIF output, but no output file specified" if $outputFormat =~ /\bsarif\b/ && !defined $options{sarif_output_file};
    push @errs, "ERROR: non-option arguments not allowed @ARGV" if @ARGV;

    foreach my $name (keys %writerOptionsData)	{
	next unless exists $writerOptionsData{$name}{validValues};
	my $v = $options{$name};
	my $validValues = $writerOptionsData{$name}{validValues};
	my %validValues = map { $_ => 1 } @$validValues;
	my $type = $writerOptionsData{$name}{type};
	my @values;
	if ($type =~ /[@]$/)  {
	    @values = split /[,;:\s]+/, $v;
	    $options{$name} = \@values;
	}  else  {
	    push @values, $v;
	}

	foreach my $value (@values)  {
	    if (!exists $validValues{$value})  {
		push @errs, "ERROR: WriterOption '$name' value '$value' invalid, valid are " . @$validValues;
	    }
	}
    }

    if ($options{help})  {
	PrintUsage(\%options);
	exit 0;
    }

    if ($options{version})  {
	PrintVersion(\%options);
	exit 0;
    }

    print STDERR map {"$_\n"} @errs if @errs;
    if (!$ok)  {
	PrintUsage(\%options);
	exit 1;
    }

    my %writerOptions;
    foreach my $name (keys %writerOptionsData)	{
	$writerOptions{$name} = $options{$name} if exists $options{$name};
    }
    $options{writerOptions} = \%writerOptions;

    return \%options;
}


sub ParseFiles
{
    my ($self) = @_;

    my $assessCnt = 0;
    foreach my $a (@{$self->{ps}{assessments}})  {
	++$assessCnt;
	$self->{curAssess} = $a;
	my $fn = $a->{report};
	if (!defined $fn || $fn eq '')	{
	    my $summaryFn = $self->{options}{summary_file};
	    my $xpath = "assessment-summary/assessment-artifacts/assessment[$assessCnt]/report";
	    my $msg = "ERROR: Inavalid assessment summary file, Missing element '$xpath' in file '$summaryFn'";
	    my $weaknessCountFile = $self->{options}{weakness_count_file};
	    PrintWeaknessCountFile($weaknessCountFile, 0, 'FAIL', $msg);
	    die $msg;
	}  elsif (!Util::IsAbsolutePath($fn))  {
	    $fn = $self->{options}{input_dir} . "/$fn";
	}

	$self->{ParseFileProc}($self, $fn);
    }
    delete $self->{curAssess};
}


sub GetBoolParam
{
    my ($self, $k) = @_;

    return exists $self->{$k} && $self->{$k};
}


sub ParseBegin
{
    my ($self) = @_;

    $self->{startTime} = time();
    # Save ARGV array to write the conversion object
    push @{$self->{argv}}, $0;
    push @{$self->{argv}}, @ARGV;

    my $options = ProcessOptions();
    $self->{options} = $options;

    my $ps = ParseSummaryFile($options->{summary_file});
    $ps->{parser_fw} = $self->{options}{parserFw};
    $ps->{parser_fw_version} = $self->{options}{parserFwVersion};
    $self->{ps} = $ps;
    
    my $isWin = $ps->{platform_name} =~ /^windows/i;
    $self->{isWin} = $isWin;

    if (!$self->GetBoolParam('NoScarfFile'))  {
	my $writers = new MultiobjectDispatcher;
	$self->{sxw} = $writers;

	my $scarfOutputFile = $options->{scarf_output_file};
	if (defined $scarfOutputFile)  {
	    my $scarfWriter = new ScarfXmlWriter($scarfOutputFile, "utf-8");
	    $writers->AddNewObject($scarfWriter);
	}

	my $sarifOutputFile = $options->{sarif_output_file};
	if (defined $sarifOutputFile)  {
	    my $sarifWriter = new SarifJsonWriter($sarifOutputFile, "utf-8");
	    $writers->AddNewObject($sarifWriter);
	}

	$self->{sxw}->SetOptions($options->{writerOptions});

	# make packageRootDir relative to buildRootDir
	$ps->{package_root_dir} = Util::AdjustPath($ps->{build_root_dir},
	    '.', $ps->{package_root_dir},
	    $isWin);

	# create uriBaseId for assessment_report files
	my $results_root_dir = $ps->{build_root_dir};
	if ($results_root_dir =~ /(.+)\/.+/) {
	    $results_root_dir = $1."/results";
	} else {
	    die "build_root_dir is not as expected, unable to form results_root_dir";
	}
	$ps->{results_root_dir} = $results_root_dir;

	$self->{sxw}->BeginFile();
	$self->{sxw}->BeginRun($ps);

	my %toolData = (
	    driver => {
		name => $ps->{tool_name},
		version => $ps->{tool_version}
	    }
	);
	$self->{sxw}->AddToolData(\%toolData);

	my %baseIds = (
	    BUILDROOT => {
		uri => "file://" . Util::UrlEncodePath($ps->{build_root_dir})
	    },
	    PACKAGEROOT => {
		uri => Util::UrlEncodePath($ps->{package_root_dir}),
		uriBaseId => "BUILDROOT"
	    },
	    RESULTSROOT => {
		uri => "file://" . Util::UrlEncodePath($results_root_dir)
	    }
	);
	$self->{sxw}->AddOriginalUriBaseIds(\%baseIds);
	$self->{sxw}->AddInvocations($ps->{assessments});
	$self->{sxw}->BeginResults();
    }

    return $self;
}


sub ParseEnd
{
    my ($self, $count, $state, $msg) = @_;

    $count = $self->{weaknessCount} unless defined $count;
    $state = $self->{resultParserState} unless defined $state;
    $msg   = $self->{resultParserMsg} unless defined $msg;
    my $metricCount

    if (!$self->GetBoolParam('NoScarfFile'))  {
	$count = $self->{sxw}->GetNumBugs() unless defined $count;
	$metricCount = $self->{sxw}->GetNumMetrics() unless defined $metricCount;

	$self->{sxw}->EndResults();
	$self->{sxw}->AddSummary();

	my %endData;
	$endData{conversion}{tool}{driver}{name} = $self->{ps}{parser_fw};
	$endData{conversion}{tool}{driver}{version} = $self->{ps}{parser_fw_version};
	$endData{conversion}{commandLine} = BashQuoteArgList($self->{argv});
	$endData{conversion}{args} = $self->{argv};
	$endData{conversion}{workingDirectory} = getcwd();
	$endData{conversion}{startTime} = $self->{startTime};

	$self->{sxw}->EndRun(\%endData);
	$self->{sxw}->EndFile();
    }

    my $weaknessCountFile = $self->{options}{weakness_count_file};
    my $parsedResultsDataConfFile = $self->{options}{parsed_results_data_conf_file};

    PrintWeaknessCountFile($weaknessCountFile, $count, $state, $msg);
    my %extraAttrs = (
	    weaknesses	=> $count,
	    metrics	=> $metricCount,
	    state	=> $state,
	);
    $self->{sxw}->GetWriterAttrs(\%extraAttrs);
    CreateParsedResultsDataFile($parsedResultsDataConfFile, \%extraAttrs);
}

sub NewBugInstance
{
    my ($self) = @_;

    my $bug = new BugInstance();

    return $bug;
}


sub CurrentResultFile
{
    my ($self) = @_;

    return $self->{curAssess}{report};
}


sub AdjustPath
{
    my ($self, $path) = @_;

    my $curAssess = $self->{curAssess};
    my $cwd = $curAssess->{workingDirectory};
    my $baseDir = $self->{ps}{build_root_dir};
    my ($from, $to);

    if (exists $curAssess->{pathPrefixAdjustFrom})  {
	$from = qr/^$curAssess->{pathPrefixAdjustFrom}/;
	die "path-prefix-adjust/to not found, when path-prefix-adjust/from was"
	    unless exists $curAssess->{pathPrefixAdjustTo};
	$to = $curAssess->{pathPrefixAdjustTo};
    }  elsif (exists $curAssess->{replacePathTarget})  {
	# from is missing leading /
	$from = qr/^\/$curAssess->{replacePathTarget}/;
	die "replace-path/target not found, when replace-path/srcdir was"
	    unless exists $curAssess->{replacePathSrcDir};
	$to = $curAssess->{replacePathSrcDir};
	# to has extra path component
	$to =~ s/\/([^\/]*?)$//;
    }

    if (defined $path)	{
	my $fromRe = $self->{fromRe};
	if (defined $fromRe)  {
	    my $prefixMap = $self->{prefixMap};
	    $path =~ s/^($fromRe)/$prefixMap->{$1}/ if $fromRe
	}
	$path =~ s/$from/$to/ if defined $from;
	my $isWin = $self->{isWin};
	$path = Util::AdjustPath($baseDir, $cwd, $path, $isWin);
    }

    return $path;
}


sub AdjustBugPath
{
    my ($self, $bug) = @_;
    my $curAssess = $self->{curAssess};
    my $cwd = $curAssess->{workingDirectory};
    my $baseDir = $self->{ps}{build_root_dir};
    my ($from, $to);

    foreach my $bugLoc (@{$bug->{BugLocations}})  {
	next unless defined $bugLoc;
	next if $bugLoc->{noAdjustPath};
	my $path = $bugLoc->{SourceFile};
	if (defined $path)  {
	    $path = $self->AdjustPath($path);
	    $bugLoc->{SourceFile} = $path;
	}
    }
}

sub AppendBugFlowToBugMsg
{
    my ($self, $bug) = @_;

    $bug->AppendBugFlowToBugMsg();
}


sub WriteBugObject
{
    my ($self, $bug) = @_;

    $bug->setBugBuildId($self->{curAssess}{"build-artifact-id"});
    $bug->setBugReportPath($self->{curAssess}{report})
    unless defined $bug->getBugReportPath();

    $self->AdjustBugPath($bug);

    $self->AppendBugFlowToBugMsg($bug);

    # 1. Force last location to be primary if no locations are primary
    # 2. findbugs and pmd sometimes uses setClassAttribs() instead of setBugLocation,
    #	 so get the start/end line from there if so.

    my $foundPrimary = 0;
    my $elementsRemaining = @{$bug->{BugLocations}};
    foreach my $location (@{$bug->{BugLocations}}) {
	next unless defined $location;

	$foundPrimary = 1 if $location->{primary} eq 'true';
	--$elementsRemaining;
	my $forcePrimary = !($elementsRemaining || $foundPrimary);
	if ($forcePrimary) {
	    $location->{primary} = 'true';
	}

	if (!$location->{StartLine} && $bug->{ClassStartLine} ) {
	    $location->{StartLine} = $bug->{ClassStartLine};
	}
	if (!$location->{EndLine} && $bug->{ClassEndLine}) {
	    $location->{EndLine} = $bug->{ClassEndLine};
	}
    }

    $self->{sxw}->AddResult($bug);
}


sub AdjustMetricsPaths
{
    my ($self, $metrics) = @_;

    foreach my $m (values %$metrics)  {
	my $fileMetrics = $m->{'file-stat'};
	my $funcMetrics = $m->{'func-stat'};
	if (defined $fileMetrics)  {
	    my $path = $fileMetrics->{file};
	    $path = $self->AdjustPath($path);
	    $fileMetrics->{file} = $path;
	}
	if (defined $funcMetrics)  {
	    foreach my $func (values %$funcMetrics)  {
		my $path = $func->{file};
		$path = $self->AdjustPath($path);
		$func->{file} = $path;
	    }
	}
    }
}


sub WriteMetrics
{
    my ($self, $metrics) = @_;

    $self->AdjustMetricsPaths($metrics);

    foreach my $file (keys %{$metrics})  {
	foreach my $type (keys %{$metrics->{$file}})  {
	    if ($type eq "func-stat")  {
		foreach my $function (keys %{$metrics->{$file}{$type}})  {
		    $self->writeMetric($metrics->{$file}{$type}{$function});
		}
	    } elsif ($type eq "file-stat") {
		$self->writeMetric($metrics->{$file}{$type});
	    } else {
		die "Unknown type '$type' for metric for file '$file'";
	    }
	}
    }
}

sub writeMetric {
    my ($self, $metric) = @_;

    my %hash;
    $hash{SourceFile} = $metric->{"file"};

    if (defined $metric->{function} && $metric->{function} ne "") {
	$hash{Method} = $metric->{function};
    }
    if (defined $metric->{class} && $metric->{class} ne "") {
	$hash{Class} = $metric->{class};
    }

    if (!defined $metric->{metrics}) {
	return;
    }

    foreach my $type (keys %{$metric->{metrics}}) {
	if ($type !~ /^((blank|total|comment|code)-lines|language|ccn|params|token)$/) {
	    die "unknown metric type '$type'";
	}
	$hash{Type} = $type;
	$hash{Value} = $metric->{metrics}{$type};
	$self->{sxw}->AddMetric(\%hash);
    }
}

sub new
{
    my $invocant = shift;

    my $class = ref($invocant) || $invocant;
    my $self = { @_ };
    bless($self, $class);

    $self->ParseBegin();

    $self->ParseFiles() if ($self->{ParseFileProc});

    $self->ParseEnd();

    return $self;
}

sub HasBashMetaChars {
    my $s = shift;
    return ($s !~ /^$bashNonMetaChars*$/);
}

sub BashQuote {
    my $s = shift;

    my @a = split /(')/, $s;
    foreach (@a) {
	if (HasBashMetaChars($_)) {
	    if ($_ eq "'") {
		$_ = "\\'";
	    } else {
		$_ = "'$_'";
	    }
	}
    }
    return join('', @a);
}

sub BashQuoteArgList {
    my ($c) = @_;
    my @cmd = @{$c};
    my $s = join ' ', map {BashQuote $_} @cmd;
    return $s;
}

1;
