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

    my $jsonObject = JSON->new->utf8->decode($jsonData);

    foreach my $error (@{$jsonObject->{"errors"}})  {
	WriteFlowWeakness($parser, $error);
    }
}


sub WriteFlowWeakness  {
    my ($parser, $e) = @_;

    my $bug = $parser->NewBugInstance();

    $bug->setBugGroup($e->{kind}) if exists $e->{kind};
    $bug->setBugSeverity($e->{level}) if exists $e->{level};
    my $msgs = $e->{message};

    my $bugCode;
    my $bugMsg;
    my $isPrimary = "true";
    my $locCount = 0;
    foreach my $msg (@$msgs)  {
	++$locCount;
	my $type = $msg->{type};
	if (!defined $bugCode || $type eq 'Comment' && !defined  $msg->{context})  {
	    $bugCode = $msg->{descr};
	}
	$bugMsg .= ' ' if defined $bugMsg;
	my $locMsg = $msg->{descr};
	$bugMsg .= $locMsg;
	
	if (exists $msg->{loc} && $type ne 'libFile')  {
	    my $loc = $msg->{loc};
	    my $startLine = $loc->{start}{line};
	    my $startCol = $loc->{start}{column};
	    my $endLine = $loc->{end}{line};
	    my $endCol = $loc->{end}{column};
	    my $file = $loc->{source};

	    $bug->setBugLocation($locCount, '', $file, $startLine, $endLine,
				    $startCol, $endCol, $locMsg, $isPrimary, 'true');

	    $isPrimary = 'false';
	}
    }

    # make error message generic instead of including the named export
    $bugCode =~ s/called (['"`]).*?\1/called `*`/g;

    $bug->setBugCode($bugCode);
    $bug->setBugMessage($bugMsg);

    $parser->WriteBugObject($bug);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
