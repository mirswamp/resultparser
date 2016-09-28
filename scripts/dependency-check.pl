#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
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
my $tempInputFile;


my $xmlWriterObj = new xmlWriterObject($outputFile);
$xmlWriterObj->addStartTag($toolName, $toolVersion, $uuid);

foreach my $inputFile (@inputFiles)  {
    my $twig = XML::Twig->new(
	    twig_roots    => {'analysis/dependencies' => 1},
	    twig_handlers => {'dependency'  => \&ParseDependency}
    );
    $tempInputFile = $inputFile;
    $buildId        = $buildIds[$count];
    $count++;
    $twig->parsefile("$inputDir/$inputFile");
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if (defined $weaknessCountFile)  {
    Util::PrintWeaknessCountFile($weaknessCountFile, $xmlWriterObj->getBugId() - 1);
}

my $depNum = 0;

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

sub ParseDependency {
    my ($tree, $elem) = @_;
    my $vulnerabilities = $elem->first_child('vulnerabilities');
    if ($vulnerabilities)  {
	my @vulnerabilities = $vulnerabilities->children('vulnerability');
	my $filePath = $elem->first_child('filePath')->text();
	my $md5 = $elem->first_child('md5')->text();
	my $sha1 = $elem->first_child('sha1')->text();
	my $pDesc = $elem->first_child('description')->text();
	my $license = $elem->first_child('license')->text();
	my @identifiers;
	my $identifiers = $elem->first_child('identifiers');
	if ($identifiers)  {
	    foreach my $i ($identifiers->children('identifier'))  {
		my $type = $i->att('type');
		my $confidence = $i->att('confidence');
		my $name = $i->first_child('name')->text();
		my $url = GetOptionalElemText($i, 'url');
		my %ident = (
				type => $type,
				confidence => $confidence,
				name => $name,
				url => $url
			    );
		push @identifiers, \%ident;
	    }
	}
	my $vulnNum = 0;
	foreach my $v (@vulnerabilities)  {
	    my $name = $v->first_child('name')->text();
	    my $cvssScore = $v->first_child('cvssScore')->text();
	    my $severity = $v->first_child('severity')->text();
	    my $vDesc = $v->first_child('description')->text();
	    my @refs;
	    my $references = $v->first_child('references');
	    if ($references)  {
		foreach my $r ($references->children('reference'))  {
		    my $name = $r->first_child('name')->text();
		    my $source = $r->first_child('source')->text();
		    my $url = GetOptionalElementText($r, 'url');
		    my %ref = (name => $name, source => $source, url => $url);
		    push @refs, \%ref;
		}
	    }
	    my @vulnVers;
	    my $vulnVers = $v->first_child('vulnerableSoftware');
	    if ($vulnVers)  {
		foreach my $s ($vulnVers->children('software'))  {
		    my $software = $s->text();
		    my $allPrev = $s->att('allPreviousVersion') eq 'true';
		    my %s = (software => $software, allPrev => $allPrev);
		    push @vulnVers, \%s;
		}
	    }
	    my $xpath = "/analysis/dependencies/dependency[$depNum]/vulnerabilities/vulnerability[$vulnNum]";
	    my $adjustedPath = Util::AdjustPath($packageName, $cwd, $filePath);

	    my $msg = "$vDesc\n";

	    $msg .= "\n" if @refs;
	    foreach my $r (@refs)  {
		my $url = $r->{url};
		$msg .= "    - $r->{source}  -  $r->{name}";
		$msg .= " ($url)" if $url;
		$msg .= "\n";
	    }

	    $msg .= "\n Vulnerable Versions:\n\n" if @vulnVers;
	    foreach my $s (@vulnVers)  {
		$msg .= "    - $s->{software}";
		$msg .= " (and all previous versions)" if $s->{allPreviousVersions};
		$msg .= "\n";
	    }

	    $msg .= "\nIdentifiers:\n" if @identifiers;
	    foreach my $i (@identifiers)  {
		my $url = $i->{url};
		$msg .= "    - $i->{type}: $i->{name}";
		$msg .= " ($url)" if $url;
		$msg .= "   confidence: $i->{confidence}\n";
	    }

	    my $bug = new bugInstance($xmlWriterObj->getBugId());
	    $bug->setBugGroup('CVE');
	    $bug->setBugCode($name);
	    $bug->setBugPath($xpath);
	    $bug->setBugBuildId($buildId);
	    $bug->setBugSeverity($severity);
	    $bug->setBugReportPath($tempInputFile);
	    $bug->setBugMessage($msg);
	    $bug->setBugLocation(0, '', $adjustedPath,
			undef, undef, '0', '0', '', 'true', 'true');
	    $xmlWriterObj->writeBugObject($bug);
	    undef $bug;

	    ++$vulnNum
	}
    }
    $tree->purge();
    ++$depNum;
    return;
}
