#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;
use JSON;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $jsonData = Util::ReadFile($fn);
    my $json_obj = JSON->new->utf8->decode($jsonData);

    foreach my $warning (@{$json_obj->{"vulnerabilities"}})  {
	my $bug = $parser->NewBugInstance();
	my $name       = $warning->{"name"};
	my $cvss_score = $warning->{"cvss_score"};
	if (defined $cvss_score && $cvss_score ne "null")  {
	    $bug->setCWEInfo($cvss_score);
	}
	$bug->setBugCode($name);
	$bug->setBugMessage($warning->{"message"});
	$bug->setBugSeverity($warning->{"severity"});
	$bug->setBugRank($warning->{"priority"});
	$bug->setBugSuggestion($warning->{"remediation"});
	my $cveLink = $warning->{"cve_link"};

	if (defined $cveLink && $cveLink ne "null")  {
	    $bug->setURLText($cveLink);
	}  elsif ($name =~ m/^\s*CVE.*$/i)  {
	    $bug->setURLText("https://cve.mitre.org/cgi-bin/cvename.cgi?name=" . $name);
	}

	#TODO : Add links to OSDVB and OWASP codes
	$parser->WriteBugObject($bug);
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
