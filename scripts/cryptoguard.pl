#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;
use ScarfXmlReader;


sub ProcessInitial
{
    my ($initial, $data) = @_;

    print "In ProcessInitial\n";
}


sub ProcessBug
{
    my ($bugData, $data) = @_;

    my $parser = $data->{parser};
    my $count = ++$data->{count};
    my $xPath = "/AnalyzerReport/BugInstance[$count]";

    delete $bugData->{BuildId};
    delete $bugData->{AssessmentReportFile};
    delete $bugData->{InstanceLocation};

    my $bug = $parser->NewBugInstance($bugData);
    $bug->setBugPath($xPath);

    $parser->WriteBugObject($bug);
}


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $reader = new ScarfXmlReader($fn);

    my $data = {
		    parser	=> $parser,
		    count	=> 0
		};

    $reader->SetInitialCallback(\&ProcessInitial);
    $reader->SetBugCallback(\&ProcessBug);
    $reader->SetCallbackData($data);

    $reader->Parse();
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
