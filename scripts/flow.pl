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


# make error message generic instead of including names of objects
sub DescToBugCode
{
    my ($s) = (@_);

    $s =~ s/(^|\s*)(\`(['"]).*?\3\`|\`.*?\`)/$1?/sg;
    $s =~ s/\s*Did you mean.*\?$//s;
    $s =~ s/\s+\[\d+\]//g;
    $s =~ s/(^|\s*)\d+(\s*|$)/$1?$2/g;
    $s =~ s/(^| )(((empty )?string|number|boolean|(array|object|function) types?|(empty )?array( element)?|object|function)( literal( \?)?)?|global object|null or undefined|null|possibly uninitialized variable|statics|uninitialized variable|empty|new object|undefined|property \?( of unknown type)?|(generator|async) function|(module|class) \?|new Function\(\.{2,}\)|return value|first parameter|second argument|exports|prototype|enum|\? type|(\? )?super( \?)?|type argument)/$1?/g;
    $s =~ s/\bthe\s+//g;
    $s =~ s/\?(\s+(in\s+)?\?)+/?/g;
    $s =~ s/[\s.:]*$//;
    $s =~ s/(^| )\? is /$1/;
    $s =~ s/(:\s+Either)(\s+(?:\? is )?(.*?))(?:\.\s+Or\s*(?:\? is )?\3)+$/DescToBugCode($2)/es;
    $s =~ s/(\s+(in|with|of|using|by)\s+\?)*$//;
    $s =~ s/^(Cannot call because) no .*argument.*by (\?|Function).*/$1 argument count/;
    $s =~ s/\ban \?/a ?/g;
    $s =~ s/ \? (to|and) \?//g;
    $s =~ s/( \?,?)* or \?/ ?/g;
    $s =~ s/^\*{3,}\s+|\s+\*{3,}//g;
    $s =~ s/(\s\?\s+\w+)\s+is/$1s are/g;
    $s =~ s/\. .*$//;
    $s =~ s/^(Experimental )\? (usage)\.\s+.*/$1$2/s;
    $s =~ s/^(Unexpected token)\s+.*/$1/s;
    $s =~ s/^(Internal error):\s+.*/$1/s;
    $s =~ s/^(Cannot resolve \w+) \?$/$1/;
    $s =~ s/^(Cannot call) \?/$1/;
    $s =~ s/^(Could not decide which case to select)\.\s+.*/$1/s;
    $s =~ s/^(Missing type annotation) for \?\.\s+.*/$1/s;
    $s =~ s/^(Unable to determine module type) .*/$1/s;
    $s =~ s/^\?\s+//;

    return $s;
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
	    $bugCode = DescToBugCode($msg->{descr});
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

    $bug->setBugCode($bugCode);
    $bug->setBugMessage($bugMsg);

    $parser->WriteBugObject($bug);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
