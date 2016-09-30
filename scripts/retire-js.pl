#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use JSON;
use xmlWriterObject;
use Util;

my ($inputDir, $outputFile, $toolName, $summaryFile, $weaknessCountFile, $help, $version);

GetOptions(
	"input_dir=s"           => \$inputDir,
	"output_file=s"         => \$outputFile,
	"tool_name=s"           => \$toolName,
	"summary_file=s"        => \$summaryFile,
	"weakness_count_file=s" => \$weaknessCountFile,
	"help"                  => \$help,
	"version"               => \$version
) or die("Error");

Util::Usage()   if defined $help;
Util::Version() if defined $version;

$toolName = Util::GetToolName($summaryFile) unless defined $toolName;

my @parsedSummary = Util::ParseSummaryFile($summaryFile);
my ($uuid, $packageName, $buildId, $input, $cwd, $replaceDir, $toolVersion, @inputFiles)
	= Util::InitializeParser(@parsedSummary);
my @buildIds = Util::GetBuildIds(@parsedSummary);
undef @parsedSummary;
my $count = 0;

my $depNum;


my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    $buildId        = $buildIds[$count];
    $count++;
    ParseFile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}


sub GetOptionalElemText
{
    my ($elem, $child) = @_;

    my $c = $elem->first_child($child);

    if ($c)  {
	return $c->text();
    }  else  {
	return;
    }
}


sub GetValueIfExists
{
    my ($h, $k) = @_;

    return unless exists $h->{$k};

    return $h->{$k};
}


sub DisplayId
{
    my ($prefix, $id, $sep) = @_;

    if (ref $id eq '')  {
	return "$prefix$id";
    }  elsif (ref $id eq 'ARRAY')  {
	return join $sep, map {"$prefix$_"} @$id;
    }  else  {
	die "Bad identifier data, not ARRAY or SCALAR " . (ref $id);
    }
}


sub GetIdData
{
    my ($component, $v) = @_;

    my ($bugCode, $summary, $idText);

    if (exists $v->{identifiers})  {
	my $ids = $v->{identifiers};
	my @nonSummaryTypes = grep {!/summary/} sort keys %$ids;

	my @types = (qw/CVE issue bug advisory commit release/, @nonSummaryTypes);

	foreach my $type (@types)  {
	    if (exists $ids->{$type})  {
		my $id = $ids->{$type};
		my $prefix = '';
		$prefix = "$component-$type-" unless $type eq 'CVE';
		$bugCode = DisplayId($prefix, $id, ',');
		last;
	    }
	}
	$summary = $ids->{summary} if exists $ids->{summary};
	$idText = join "\n",
		    map {"  - $_:  " . DisplayId('', $ids->{$_}, ', ')}
			@nonSummaryTypes
			    if @nonSummaryTypes;
    }

    $bugCode = "$component-Unknown" unless defined $bugCode;

    return ($bugCode, $summary, $idText);
}


sub GetDependencyText
{
    my ($result) = @_;

    return unless $result->{parent};

    my $s = '';

    while (1)  {
	my $component = $result->{component};
	my $version = $result->{version};
	$s .= sprintf "  %-30s  version %-15s", $component, $version;
	$s .= " required by" if exists $result->{level};
	$s .= "\n";
	last unless exists $result->{parent};
	$result = $result->{parent};
    }

    return $s;
}


sub ParseFile
{
    my ($jsonFn) = @_;
    my $data;

    {
	local $/;
	open FILE, "<$jsonFn" or die "open $jsonFn: $!";
	$data = <FILE>;
	close FILE;
    }

    my $json = JSON->new->utf8->decode($data);

    my $num = -1;
    foreach my $group (@$json)  {
	++$num;
	my $file;
	$file = $group->{file} if exists $group->{file};
	my $adjustedPath
		= Util::AdjustPath($packageName, $cwd, $file) if defined $file;;
	if (exists $group->{results})  {
	    my $resultNum = -1;
	    foreach my $r (@{$group->{results}})  {
		++$resultNum;
		my $resultJsonPath = "\$[$num].results[$resultNum]";
		my $component = GetValueIfExists($r, 'component');
		my $version = GetValueIfExists($r, 'version');
		my $detection = GetValueIfExists($r, 'detection');
		my $dependencyText = GetDependencyText($r);
		if (exists $r->{vulnerabilities})  {
		    my $vulnNum = -1;
		    foreach my $v (@{$r->{vulnerabilities}})  {
			++$vulnNum;
			my $vulnJsonPath = "$resultJsonPath.vulnerabilities[$vulnNum]";
			my $severity = GetValueIfExists($v, 'severity');
			my $info = GetValueIfExists($v, 'info');
			$info = [] unless defined $info;
			my $bugGroup = 'Known-Vuln';
			my ($bugCode, $summary, $idText) = GetIdData($component, $v);
			my $msg = "Known vulnerabilities in component $component version $version";
			$msg .= "\n(detected by $detection)" if defined $detection;
			$msg .= ":";
			$msg .= "\n\n$summary" if defined $summary;
			$msg .= "\n\nIdentifiers:\n\n$idText" if $idText;
			$msg .= "\n\nDependencies:\n\n$dependencyText" if $dependencyText;
			if (exists $v->{info} && @{$v->{info}})  {
			    $msg .= "\n\nMore Inforation:\n\n";
			    $msg .= join "\n", map {" - $_"} @{$v->{info}};
			}

			my $bug = new bugInstance($xmlWriterObj->getBugId());
			$bug->setBugGroup($bugGroup);
			$bug->setBugCode($bugCode);
			$bug->setBugPath($vulnJsonPath);
			$bug->setBugBuildId($buildId);
			$bug->setBugSeverity($severity) if defined $severity;;
			$bug->setBugReportPath($jsonFn);
			$bug->setBugMessage($msg);
			$bug->setBugLocation(0, '', $adjustedPath, undef, undef,
			    '0', '0', '', 'true', 'true') if defined $adjustedPath;
			$xmlWriterObj->writeBugObject($bug);
			undef $bug;

		    }
		}
	    }
	}  else  {
	    die "Error: no results in $jsonFn \$[$num]"
	}
    }
}
