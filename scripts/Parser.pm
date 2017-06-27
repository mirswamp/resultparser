#!/usr/bin/perl -w

package Parser;

use strict;
use Getopt::Long;
# use Util;
use xmlWriterObject;
use XML::Twig;
use FindBin;



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
	assessUuid	=> undef,
	buildRootDir	=> undef,
	packageRootDir	=> undef,
	toolType	=> undef,
	toolVersion	=> undef,
	assessments	=> [],
	);
    my $curAssess = {};	# in-progress parsing of assessment
			# keys: buildId, report, cwd
			#       replacePathTarget, replacePathSrcDir,
			#       pathPrefixAdjustFrom, pathPrefixAdjustTo

    my $as = "/assessment-summary";
    my $assess = "$as/assessment-artifacts/assessment";

    my $twig = XML::Twig->new(
		twig_handlers => {
		    "$as/assessment-summary-uuid"	=> sub {
			my ($twig, $e) = @_;
			$s{assessUuid} = GetElemText($e);
			return 1;
		    },
		    "$as/build-root-dir"		=> sub {
			my ($twig, $e) = @_;
			$s{buildRootDir} = GetElemText($e);
			return 1;
		    },
		    "$as/package-root-dir"		=> sub {
			my ($twig, $e) = @_;
			$s{packageRootDir} = GetElemText($e);
			return 1;
		    },
		    "$as/package-name"			=> sub {
			my ($twig, $e) = @_;
			$s{packageName} = GetElemText($e);
			return 1;
		    },
		    "$as/package-version"		=> sub {
			my ($twig, $e) = @_;
			$s{packageVersion} = GetElemText($e);
			return 1;
		    },
		    "$as/platform-name"			=> sub {
			my ($twig, $e) = @_;
			$s{platformName} = GetElemText($e);
			return 1;
		    },
		    "$as/platform-uuid"			=> sub {
			my ($twig, $e) = @_;
			$s{platformUuid} = GetElemText($e);
			return 1;
		    },
		    "$as/tool-type"			=> sub {
			my ($twig, $e) = @_;
			$s{toolType} = GetElemText($e);
			return 1;
		    },
		    "$as/tool-version"			=> sub {
			my ($twig, $e) = @_;
			$s{toolVersion} = GetElemText($e);
			return 1;
		    },
		    "$as/start-ts"			=> sub {
			my ($twig, $e) = @_;
			$s{startTs} = GetElemText($e);
			return 1;
		    },
		    "$as/stop-ts"			=> sub {
			my ($twig, $e) = @_;
			$s{stopTs} = GetElemText($e);
			return 1;
		    },
		    "$as/build-fw"			=> sub {
			my ($twig, $e) = @_;
			$s{buildFw} = GetElemText($e);
			return 1;
		    },
		    "$as/build-fw-version"		=> sub {
			my ($twig, $e) = @_;
			$s{buildFwVersion} = GetElemText($e);
			return 1;
		    },
		    "$as/assess-fw"			=> sub {
			my ($twig, $e) = @_;
			$s{assessFw} = GetElemText($e);
			return 1;
		    },
		    "$as/assess-fw-version"		=> sub {
			my ($twig, $e) = @_;
			$s{assessFwVersion} = GetElemText($e);
			return 1;
		    },
		    "$assess"				=> sub {
			my ($twig, $e) = @_;
			push @{$s{assessments}}, $curAssess;
			$twig->purge();
			$curAssess = {};
			return 1;
		    },
		    "$assess/build-artifact-id"		=> sub {
			my ($twig, $e) = @_;
			$curAssess->{buildId} = GetElemText($e);
			return 1;
		    },
		    "$assess/report"			=> sub {
			my ($twig, $e) = @_;
			$curAssess->{report} = GetElemText($e);
			return 1;
		    },
		    "$assess/command/cwd"		=> sub {
			my ($twig, $e) = @_;
			$curAssess->{cwd} = GetElemText($e);
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

    my @required = qw/assessUuid buildRootDir packageRootDir toolType toolVersion/;
    my @missing;
    foreach my $k (@required)  {
	push @missing, $k unless defined $s{$k};
    }
    die "assessment-summary xml file missing required elements: @missing"
	    if @missing;

    return \%s;
}


sub GetToolName {
    my $assessment_summary_file = shift;
    my $toolName;
    my $twig                    = XML::Twig->new(
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


sub PrintWeaknessCountFile {
    my ($fn, $weaknessCount, $status, $longMsg) = @_;

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
    --input_dir=<PATH>              directory containing results
    --summary_file=<PATH>           path to assessment_summary.xml
    --output_file=<PATH>            path to scarf file
    --weakness_count_file=<PATH>    path to weakness count file
    --help        -v                print this message and exit
    --version     -h                print the version number
EOF
}


sub ProcessOptions
{
    my %opts = @_;

    my %options = (
	    input_dir			=> '.',
	    summary_file		=> undef,
	    output_file			=> undef,
	    tool_name			=> undef,
	    weakness_count_file		=> undef,
	    help			=> undef,
	    version			=> undef,
	    );
    my @options = (
	    "input_dir=s",
	    "output_file=s",
	    "tool_name=s",
	    "summary_file=s",
	    "weakness_count_file=s",
	    "help|h!",
	    "version|v!",
	    );

    my $deprecatedOptions = 1;
    if ($deprecatedOptions)  {
	$options{log_file} = undef;
	$options{output_dir} = undef;
	push @options, "log_file=s", "output_dir=s";
    }

    Getopt::Long::Configure(qw/require_order no_ignore_case no_auto_abbrev/);
    my $ok = GetOptions(\%options, @options);

    my @errs;

    for my $opt (qw/summary_file output_file/)  {
	if (!defined $options{$opt})  {
	    $ok = 0;
	    push @errs, "Error: --$opt must be specified";
	}
    }

    if ($deprecatedOptions)  {
	if (defined $options{log_file})  {
	    push @errs, "WARNING: --log_file is deprecated, do NOT use.";
	}
	if (defined $options{output_dir})  {
	    push @errs, "WARNING: --output_dir is deprecated, do NOT use.";
	    my $outDir = $options{output_dir};
	    my $outputFile = $options{output_file};
	    if ($outputFile !~ /^\//)  {
		$options{output_file} = "$outDir/$outputFile";
	    }
	    my $weaknessCountFile = $options{weakness_count_file};
	    if ($weaknessCountFile !~ /^\//)  {
		$options{weakness_count_file} = "$outDir/$weaknessCountFile";
	    }
	}
    }

    my $v = 'unknown';
    my $versionFile = "$FindBin::Bin/version.txt";
    $v = Util::ReadFile($versionFile) if -f $versionFile;
    $v =~ s/\s*$//;
    $options{parserFwVersion} = $v;
    $options{parserFw} = 'resultparser';
    $options{parserBin} = $0;
    $options{parserBin} =~ s/^.*\///;

    if (@ARGV)  {
	push @errs, "ERROR: non-option arguments not allowed @ARGV";
	$ok = 0;
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
	if (!defined $fn || $fn eq '')  {
	    my $summaryFn = $self->{options}{summary_file};
	    my $xpath = "assessment-summary/assessment-artifacts/assessment[$assessCnt]/report";
	    my $msg = "Missing element 'report' at '$xpath' in file '$summaryFn'";
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

    my $options = ProcessOptions();
    $self->{options} = $options;

    my $ps = ParseSummaryFile($options->{summary_file});
    $self->{ps} = $ps;

    if (!$self->GetBoolParam('NoScarfFile'))  {
	my $xmlOut = new xmlWriterObject($options->{output_file});
	$self->{xmlOut} = $xmlOut;

	# make packageRootDir relative to buildRootDir
	$ps->{packageRootDir} = Util::AdjustPath($ps->{buildRootDir},
						'.', $ps->{packageRootDir});

	$xmlOut->addStartTag(
		@{$ps}{qw/toolType toolVersion assessUuid
		    startTs packageName packageVersion
		    platformName buildRootDir packageRootDir
		    buildFw buildFwVersion assessFw assessFwVersion
		    /},
		@{$self->{options}}{qw/parserFw parserFwVersion/}
		);
    }

    return $self;
}


sub ParserEnd
{
    my ($self, $count, $state, $msg) = @_;

    my $xmlOut = $self->{xmlOut};

    $count = $self->{weaknessCount} unless defined $count;
    $state = $self->{resultParserState} unless defined $state;
    $msg   = $self->{resultParserMsg} unless defined $msg;

    if (!$self->GetBoolParam('NoScarfFile'))  {
	$count = $xmlOut->getBugId() - 1 unless defined $count;
	$xmlOut->writeSummary();
	$xmlOut->addEndTag();
    }

    my $weaknessCountFile = $self->{options}{weakness_count_file};

    PrintWeaknessCountFile($weaknessCountFile, $count, $state, $msg);
}


sub NewBugInstance
{
    my ($self) = @_;

    my $bug = new bugInstance($self->{xmlOut}->getBugId() - 1);

    return $bug;
}


sub AdjustPath
{
    my ($self, $path) = @_;

    my $curAssess = $self->{curAssess};
    my $cwd = $curAssess->{cwd};
    my $baseDir = $self->{ps}{buildRootDir};
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

    if (defined $path)  {
	my $fromRe = $self->{fromRe};
	if (defined $fromRe)  {
	    my $prefixMap = $self->{prefixMap};
	    $path =~ s/^($fromRe)/$prefixMap->{$1}/ if $fromRe
	}
	$path =~ s/$from/$to/ if defined $from;
	$path = Util::AdjustPath($baseDir, $cwd, $path);
    }

    return $path;
}


sub AdjustBugPath
{
    my ($self, $bug) = @_;
    my $curAssess = $self->{curAssess};
    my $cwd = $curAssess->{cwd};
    my $baseDir = $self->{ps}{buildRootDir};
    my ($from, $to);

    foreach my $bugLoc (@{$bug->{_bugLocations}})  {
	next unless defined $bugLoc;
	my $path = $bugLoc->{_sourceFile};
	if (defined $path)  {
	    $path = $self->AdjustPath($path);
	    $bugLoc->{_sourceFile} = $path
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

    $bug->setBugBuildId($self->{curAssess}{buildId});
    $bug->setBugReportPath($self->{curAssess}{report})
	    unless defined $bug->getBugReportPath();

    $self->AdjustBugPath($bug);

    $self->AppendBugFlowToBugMsg($bug);

    $self->{xmlOut}->writeBugObject($bug);
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

    $self->{xmlOut}->writeMetricObjectUtil($metrics);
}




sub new
{
    my $invocant = shift;

    my $class = ref($invocant) || $invocant;
    my $self = { @_ };
    bless($self, $class);

    $self->ParseBegin();

    if ($self->{ParseFileProc})  {
	$self->ParseFiles();
	$self->ParserEnd();
    }

    return $self;
}


1;
