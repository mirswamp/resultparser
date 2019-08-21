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

    # make error message generic instead of including names of objects
    $bugCode =~ s/(^| )(((empty )?string|number|boolean|(empty )?array( element)?|object|function)( literal( `\S*?`)?)?|global object|null or undefined|null|possibly uninitialized variable|statics|uninitialized variable|empty|new object|undefined|property \`\S*?\` of unknown type)/$1?/g;
    $bugCode =~ s/\`.*?\`/?/g;
    $bugCode =~ s/\s+\[\d+\]//g;
    $bugCode =~ s/\s*[.:]$//;
    $bugCode =~ s/^(Cannot resolve \w+) \?$/$1/;
    $bugCode =~ s/^\? is //;
    $bugCode =~ s/(Cannot call \? because): Either \? is (incompatible) with \?(\.\s+Or \? is incompatible with \?)*$/$1 $2/;
    $bugCode =~ s/(\s+(in|with|of|using)\s+\?)*$//;
    $bugCode =~ s/^(Cannot call) \?/$1/;
    $bugCode =~ s/^(Cannot call because) no .*argument.*by (\?|Function).*/$1 argument count/;
    $bugCode =~ s/ \? is//g;
    $bugCode =~ s/an \?/a ?/g;
    $bugCode =~ s/ \? (to|and) \?//g;

    $bug->setBugCode($bugCode);
    $bug->setBugMessage($bugMsg);

    $parser->WriteBugObject($bug);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
