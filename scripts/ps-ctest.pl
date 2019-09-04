#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use XML::Twig;
use Util;

my $resultsSessionXpath = '/ResultsSession';
my $locXpath = "$resultsSessionXpath/Scope/Locations/Loc";

#Initialize the counter values
my $locationId   = 0;


sub ParseProjectFile
{
    my ($parser, $projectFile, $proj) = @_;

    $projectFile = $parser->{options}{input_dir} . "/$projectFile";

    # Jtest does not a .proj file, so skip
    return unless -f $projectFile;

    my $linkedResourcesXpath	= '/projectDescription/linkedResources';
    my $linkXpath		= "$linkedResourcesXpath/link";
    my $nameXpath		= "$linkXpath/name";
    my $locationXpath		= "$linkXpath/location";

    my $numLinkedResources = 0;
    my $numLinkRsources = 0;
    my $name;
    my $location;

    my %h;

    my $twig = XML::Twig->new(
	    twig_handlers =>  {
		$linkedResourcesXpath	=> sub {
		    my ($twig, $e) = @_;
		    ++$numLinkedResources;
		    return 1;
		},
		$linkXpath		=> sub {
		    my ($twig, $e) = @_;
		    ++$numLinkedResources;

		    die "$nameXpath not found in $projectFile"
			    unless defined $name;
		    die "$locationXpath not found in $projectFile"
			    unless defined $location;

		    $h{"/$proj/$name"} = $location;

		    undef $name;
		    undef $location;

		    return 1;
		},
		$nameXpath		=> sub {
		    my ($twig, $e) = @_;
		    $name = $e->text();
		    return 1;
		},
		$locationXpath		=> sub {
		    my ($twig, $e) = @_;
		    $location = $e->text();
		    return 1;
		},
	    },
    );

    $twig->parsefile($projectFile);

    if (%h)  {
	my $fromText = join '|', keys %h;
	my $fromRe = qr/$fromText/;
	$parser->{fromRe} = $fromRe;
	$parser->{prefixMap} = \%h;
    }
}


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $majorVersion = MajorVersion($parser->{ps}{tool_version});

    my $getViolPath;
    my $getElDescPath;
    my %hashToPath;

    if ($majorVersion < 10)  {
	# TODO: should get the parameter from the report.xml
	ParseProjectFile($parser, 'proj/.project', 'proj');
	$getViolPath = sub {
	    my ($e) = @_;
	    return $e->att('locFile');
	};
	$getElDescPath = sub {
	    my ($e) = @_;
	    return $e->att('srcRngFile');
	};
    }  else  {
	$getViolPath = sub {
	    my ($e) = @_;
	    my $hash = $e->att('hash');
	    my $msg;
	    if (defined $hash)  {
		if (exists $hashToPath{$hash})  {
		    my $path = $hashToPath{$hash};
		    return $path;
		}  else  {
		    $msg = "hash '$hash' not found in $locXpath";
		}
	    }  else  {
		my $gi = $e->gi();
		$msg = "missing 'hash' attribute for element '$gi'";
	    }

	    my $line = $e->twig()->current_line();
	    my $xmlString = $e->twig()->original_string();
	    my $sep = '';
	    $sep = ':  ' unless $xmlString eq '';
	    print STDERR "Warning: $msg at $fn:$line$sep$xmlString\n";

	    return;
	};
	$getElDescPath = sub {
	    my ($e) = @_;
	    my $hash = $e->att('srcRnghash');
	    my $path;
	    my $msg;
	    if (defined $hash)  {
		if (exists $hashToPath{$hash})  {
		    my $path = $hashToPath{$hash};
		    return $path;
		}  else  {
		    $msg = "hash '$hash' not found in $locXpath";
		}
	    }  else  {
		my $gi = $e->gi();
		$msg = "missing 'hash' attribute for element '$gi'";
	    }

	    my $line = $e->twig()->current_line();
	    my $xmlString = $e->twig()->original_string();
	    my $sep = '';
	    $sep = ':  ' unless $xmlString eq '';
	    print STDERR "Warning: $msg at $fn:$line$sep$xmlString\n";

	    return;
	};
    }

    my $stdViolNum	= 0;
    my $dupViolNum	= 0;
    my $flowViolNum	= 0;

    my $stdViolsXpath	= "$resultsSessionXpath/CodingStandards/StdViols";
    my $stdViolXpath	= "$stdViolsXpath/StdViol";
    my $dupViolXpath	= "$stdViolsXpath/DupViol";
    my $flowViolXpath	= "$stdViolsXpath/FlowViol";
    my $elDescXpath	= "ElDesc";
    my $propXpath	= "$elDescXpath/Props/Prop";

    my %curViol;
    my %locHash;


    my $twig = XML::Twig->new(
	    start_tag_handlers =>  {
		$elDescXpath	=> sub {
		    my ($twig, $e) = @_;
		    my $elDesc = GetElDesc($twig, $e, $getElDescPath);
		    push @{$curViol{elDescs}}, $elDesc;
		    push @{$curViol{openElDescs}}, $elDesc;
		    return 1;
		},
		$propXpath	=> sub {
		    my ($twig, $e) = @_;
		    my $props = $curViol{openElDescs}->[-1]{props};
		    ProcessProps($twig, $e, $props);
		    return 1;
		},
		$flowViolXpath	=> sub {
		    my ($twig, $e) = @_;
		    ++$flowViolNum;
		    my $xpath = "$flowViolXpath\[$flowViolNum]";
		    BeginFlowViol($parser, $twig, $e, $xpath, \%curViol, $getViolPath);
		    return 1;
		},
	    },
	    twig_handlers => {
		$stdViolXpath	=> sub {
		    my ($twig, $e) = @_;
		    ++$stdViolNum;
		    my $xpath = "$stdViolXpath\[$stdViolNum]";
		    ParseViolations_StdViol($parser, $twig, $e, $xpath, $getViolPath);
		    return 1;
		},
		$dupViolXpath	=> sub {
		    my ($twig, $e) = @_;
		    ++$dupViolNum;
		    my $xpath = "$dupViolXpath\[$dupViolNum]";
		    ParseViolations_DupViol($parser, $twig, $e, $xpath, $getElDescPath);
		    return 1;
		},
		$flowViolXpath	=> sub {
		    my ($twig, $e) = @_;
		    EndFlowViol($parser, $twig, $e, \%curViol);
		    return 1;
		},
		$elDescXpath	=> sub {
		    my ($twig, $e) = @_;
		    pop @{$curViol{openElDescs}};
		    return 1;
		},
		$locXpath	=> sub {
		    my ($twig, $e) = @_;
		    AddLocPath($parser, $e, \%hashToPath);
		    return 1;
		},

	    },
	);

    $twig->parsefile($fn);
}


sub GetElDesc
{
    my ($twig, $e, $getPath) = @_;

    my $file = $getPath->($e);
    my $type = $e->att('ElType');
    my $startLine = $e->att('srcRngStartln');
    $startLine = $e->att('ln') unless defined $startLine;
    my $startCol = $e->att('srcRngStartPos');
    my $endLine = $e->att('srcRngEndLn');
    $endLine = $e->att('eLn') unless defined $endLine;
    --$endLine if defined $endLine && $endLine > 0;
    my $endCol = $e->att('srcRngEndPos');
    # XXX subtract from 1 from endCol???
    --$endCol if defined $endCol && $endCol > 0;
    $endLine = $startLine unless defined $endLine;

    my %elDesc = (
	file		=> $file,
	type		=> $type,
	startLine	=> $startLine,
	endLine		=> $endLine,
	isCause		=> scalar($type =~ /C/),
	isViolPoint	=> scalar($type =~ /P/),
	isImportant	=> scalar($type =~ /\!/),
	isThrow		=> scalar($type =~ /E/),
	props		=> {},
	);

    $elDesc{startCol} = defined $startCol ? $startCol : 0;
    $elDesc{endCol} = defined $endCol ? $endCol : 0;

    return \%elDesc;
}


sub ProcessProps
{
    my ($twig, $e, $props) = @_;

    my $k = $e->att('key');
    my $v = $e->att('val');

    die "Duplicate key for props seen '$k: $v'" if exists $props->{$k};
    $props->{$k} = $v;
}


sub CreateBug
{
    my ($parser, $e, $xpath) = @_;

    my $bugCode         = $e->att('rule');
    my $bugMsg          = $e->att('msg');
    my $bugSeverity     = $e->att('sev');
    # use cat attr if defined (bugGroup not included for flow viols),
    # otherwise, prefix of code, otherwise UNKNOWN
    my $bugGroup        = $e->att('cat');
    $bugGroup = $1 if !defined $bugGroup && $bugCode =~ /^(.*)-/;
    $bugGroup = $1 if !defined $bugGroup && $bugCode =~ /^(.*)\./;
    $bugGroup = 'UNKNOWN' unless defined $bugGroup;

    my $bug = $parser->NewBugInstance();
    $bug->setBugMessage($bugMsg);
    $bug->setBugSeverity($bugSeverity);
    $bug->setBugGroup($bugGroup);
    $bug->setBugCode($bugCode);
    $bug->setBugPath($xpath) if defined $xpath;

    return $bug;
}


sub AddLocPath
{
    my ($parser, $e, $hashToPath) = @_;

    my $hash = $e->att('hash');
    my $uri = $e->att('uri');
    my $path;

    die "missing attr 'hash' of Loc" unless defined $hash;
    die "missing attr 'uri' of Loc" unless defined $uri;

    if ($uri =~ /^file:\/\/[^\/]*(\/.*)$/)  {
	# correct file URI's are file://<HOST>/<PATH>
	# <HOST> can be (and usually is) empty, and <PATH> if relative to /
	$path = $1;
    }  elsif ($uri =~ /^file:(\/[^\/].*)$/)  {
	# broken file URI's are file:/<PATH>
	# there is no host and <PATH> is relative to /
	$path = $1;
    }  else  {
	die "'uri' attr of Loc is not file://";
    }

    $hashToPath->{$hash} = $path;
}


sub ParseViolations_StdViol
{
    my ($parser, $twig, $e, $xpath, $getPath) = @_;

    my $beginLine = $e->att('ln');
    my $endLine   = $e->att('eln');
    # eln for StdViol seems to be inclusive of the range so no -1
    $endLine   = $beginLine unless defined $endLine;
    my $filePath = $getPath->($e);
    my $bug = CreateBug($parser, $e, $xpath);
    $bug->setBugLocation(
	    1, "", $filePath, $beginLine, $endLine, "0",
	    "0", "", 'true', 'true'
    );
    $parser->WriteBugObject($bug);
    $twig->purge();
}


sub ParseViolations_DupViol
{
    my ($parser, $twig, $e, $xpath, $getPath) = @_;


    $locationId = 1;
    foreach my $child_elem ($e->first_child('ElDescList')->children)  {
	my $bug = CreateBug($parser, $e, $xpath);
	my $filePath = $getPath->($child_elem);
	my $beginLine = $child_elem->att('srcRngStartln');
	my $endLine   = $child_elem->att('srcRngEndLn');
	my $beginCol  = $child_elem->att('srcRngStartPos');
	my $endCol    = $child_elem->att('srcRngEndPos');
	my $locMsg = $child_elem->att('desc');
	$bug->setBugLocation(
		$locationId, "", $filePath, $beginLine,
		$endLine, $beginCol, $endCol, "",
		$locMsg, 'false', 'true'
	);
	$parser->WriteBugObject($bug);
    }
    $twig->purge();
}


sub BeginFlowViol
{
    my ($parser, $twig, $e, $xpath, $viol, $getPath) = @_;

    my $bug = CreateBug($parser, $e, $xpath);

    $viol->{bug} = $bug;
}


sub EndFlowViol
{
    my ($parser, $twig, $e, $viol) = @_;

    my $bug = $viol->{bug};

    my $locId = 0;
    foreach my $loc (@{$viol->{elDescs}})  {
	# do not output this, if there is no path, warning already printed
	next unless defined $loc->{file};

	my ($props, $isImportant, $isCause, $isViolPoint)
		= @$loc{qw/props isImportant isCause isViolPoint/};
	next unless %$props || $isImportant || $isCause || $isViolPoint;
	my @msg;
	push @msg, "Important" if $isImportant;
	push @msg, "Violation Cause" if $isCause;
	push @msg, "Violation Point" if $isViolPoint;
	push @msg, "Throws Exception" if $loc->{isThrow};
	push @msg, map {"$_: $props->{$_}"} sort keys %$props;
	my $msg = join "; ", @msg;

	my $class = '';
	my $isPrimary = $isViolPoint ? 'true' : 'false';
	$bug->setBugLocation(++$locId, $class, $loc->{file},
		    $loc->{startLine}, $loc->{endLine},
		    $loc->{startCol}, $loc->{endCol},
		    $msg, $isPrimary, 'true');

    }

    $parser->WriteBugObject($bug);
    %$viol = ();

    $twig->purge();
}


sub MajorVersion
{
    my ($version) = @_;

    my @version = split /\./, $version;

    return $version[0];
}



my $parser = Parser->new(ParseFileProc => \&ParseFile);
