#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $jsonObject = Util::ReadJsonFile($fn);

    my $type = $jsonObject->{type};
    my $formatVersion = $jsonObject->{formatVersion};
    my $suppressedIssueCount = $jsonObject->{suppressIssueCount};

    if (!defined $type || $type ne 'Coverity issues'
	    || !defined $formatVersion || $formatVersion != 2
	    || !defined $jsonObject->{issues})  {
	die "Invalid or missing type and/or formatVersion for Coverity JSON";
    }

    my $suppressions = $jsonObject->{suppressedIssueCount};
    print "Coverity analyzer suppressed $suppressions issue"
	    . ($suppressions == 1 ? '' : 's') . "\n"
		    if defined $suppressions && $suppressions > 0;

    foreach my $issue (@{$jsonObject->{"issues"}})  {
	WriteIssue($parser, $issue);
    }
}


sub WriteIssue
{
    my ($parser, $issue) = @_;

    my $bug = $parser->NewBugInstance();

    $bug->setBugGroup($issue->{checkerName}) if exists $issue->{checkerName};
    $bug->setBugCode($issue->{subcategory}) if exists $issue->{subcategory};


    my $locCount = 0;
    foreach my $e (@{$issue->{events}})  {
	++$locCount;
	my $locMsg = '';
	$locMsg .= $e->{eventTag} if exists $e->{eventTag};
	if (exists $e->{eventDescription})  {
	    $locMsg .= ':  ' unless $locMsg eq '';
	    $locMsg .= $e->{eventDescription};
	}
	my $isPrimary = $e->{main} ? 'true' : 'false';
	my $file = $e->{filePathname};
	my $startLine = $e->{lineNumber};
	my $endLine; 
	my $startCol;
	my $endCol;
	
	$bug->setBugLocation($locCount, '', $file, $startLine, $endLine,
				$startCol, $endCol, $locMsg, $isPrimary, 'true');
    }

    $parser->WriteBugObject($bug);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
