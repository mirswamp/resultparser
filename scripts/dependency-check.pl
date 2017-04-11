#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use bugInstance;
use XML::Twig;
use Util;


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
    my ($parser, $tree, $elem, $depNum) = @_;

    ++$depNum;
    my $vulnerabilities = $elem->first_child('vulnerabilities');
    if ($vulnerabilities)  {
	my @vulnerabilities = $vulnerabilities->children('vulnerability');
	my $filePath = $elem->first_child('filePath')->text();
	my $md5 = $elem->first_child('md5')->text();
	my $sha1 = $elem->first_child('sha1')->text();
	my $pDesc = GetOptionalElemText($elem, 'description');
	my $license = GetOptionalElemText($elem, 'license');
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
	my $vulnNum = -1;
	foreach my $v (@vulnerabilities)  {
	    ++$vulnNum;
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
		    my $url = GetOptionalElemText($r, 'url');
		    my %ref = (name => $name, source => $source, url => $url);
		    push @refs, \%ref;
		}
	    }
	    my @vulnVers;
	    my $vulnVers = $v->first_child('vulnerableSoftware');
	    if ($vulnVers)  {
		foreach my $s ($vulnVers->children('software'))  {
		    my $software = $s->text();
		    my $allAttr = $s->att('allPreviousVersion');
		    my $allPrev = $allAttr && $allAttr eq 'true';
		    my %s = (software => $software, allPrev => $allPrev);
		    push @vulnVers, \%s;
		}
	    }
	    my $xpath = "/analysis/dependencies/dependency[$depNum]/vulnerabilities/vulnerability[$vulnNum]";
	    my $adjustedPath = $filePath;

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

	    my $bug = $parser->NewBugInstance();
	    $bug->setBugGroup('Known-Vuln');
	    $bug->setBugCode($name);
	    $bug->setBugPath($xpath);
	    $bug->setBugSeverity($severity);
	    $bug->setBugMessage($msg);
	    $bug->setBugLocation(0, '', $adjustedPath,
			undef, undef, '0', '0', '', 'true', 'true');
	    $parser->WriteBugObject($bug);
	}
    }
    $tree->purge();
    return;
}

sub ParseFile
{
    my ($parser, $fn) = @_;

    my $numDependencies = 0;

    my $twig = XML::Twig->new(
	    twig_roots    => {'analysis/dependencies' => 1},
	    twig_handlers => {
		'dependency'  => sub {
		    my ($twig, $e) = @_;
		    ParseDependency($parser, $twig, $e, $numDependencies);
		    ++$numDependencies;
		    return 1;
		}
	    }
	);

    $twig->parsefile($fn);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
