#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use XML::Twig;
use Util;

my @warningData;

#Initialize the counter values
my $filePath = "";
my $eventNum;
my ($line, $bugGroup, $bugCode, $filename, $method, $bugMsg, $file);
my @weaknessCategories;
my %buglocation_hash;

sub ParseFile
{
    my ($parser, $fn) = @_;
    my $resultsDir;

    if (-f $fn)  {
	if ($fn =~ /^(.*)\/.*?$/)  {
	    $resultsDir = $1;
	}  else  {
	    $resultsDir = '.';
	}
	my $analysisTwig = XML::Twig->new(
		twig_handlers => {
		    'analysis/warning'	=> \&ProcessAnalysis
		}
	    );
	$analysisTwig->parsefile($fn);
    }  elsif (-d $fn)  {
	# old CodeSonar runs set this to the result directory
	# score is undefined in this case
	$resultsDir = $fn;
	opendir DIR, $resultsDir or die "opendir $resultsDir: $!";
	while (readdir(DIR))  {
	    my $file = $_;
	    next unless -f $file && $file =~ /\.xml$/;
	    my $r = { file => $file, score => undef };
	    push @warningData, $r;
	}
	closedir DIR or die "closedir $resultsDir";
    }  else  {
	die "Result file '$fn' not found";
    }

    foreach my $warning (@warningData)  {
	my $inputFile = $warning->{file};
	my $score = $warning->{score};
	$eventNum	 = 1;
	$bugMsg = "";
	undef($method);
	undef(@weaknessCategories);
	undef($filename);
	undef($bugGroup);
	undef($bugCode);
	undef($line);
	my $file = "$resultsDir/$inputFile";
	my $filteredInput = Util::OpenFilteredXmlInputFile($file);

	my $twig = XML::Twig->new(
		twig_handlers => {
			'warning'	     => \&GetFileDetails,
			'warning/categories' => \&GetCWEDetails,
			'warning/listing'    => \&GetListingDetails
		}
	    );
	$twig->parse($filteredInput);
	my @cwes;
	foreach my $c (@weaknessCategories)  {
	    if ($c =~ /^\s*cwe:(\d+)\s*$/i)  {
		push @cwes, $1;
	    }
	}
	my $cwe;
	$cwe = $cwes[0] if @cwes;
	my $bug = $parser->NewBugInstance();
	$bug->setBugMessage($bugMsg);
	$bug->setBugSeverity($score) if defined $score;
	$bug->setBugGroup($bugGroup);
	$bug->setBugCode($bugCode);
	$bug->setCweId($cwe) if defined $cwe;
	$bug->setBugMethod(1, "", $method, "true");
	$bug->setCWEArray(@weaknessCategories);
	my @events = sort {$a <=> $b} (keys %buglocation_hash);

	foreach my $elem (sort {$a <=> $b} @events)  {
	    my $primary = ($elem eq $events[$#events]) ? "true" : "false";
	    my @tokens = split(":", $buglocation_hash{$elem}, 3);
	    $bug->setBugLocation(
		$elem, "", $tokens[0], $tokens[1],
		$tokens[1], "0", "0", "Event $elem: $tokens[2]",
		$primary, "true"
	    );
	}
	$parser->WriteBugObject($bug);
	%buglocation_hash = ();
	close $filteredInput or die "close OpenFilteredXmlInputFile: \$!=$! \$?=$?";
    }
}



sub ProcessAnalysis
{
    my ($tree, $elem) = @_;
    my $url = $elem->att('url');
    my @scores = $elem->children('score');
    my $score;
    if (@scores >= 1)  {
	$score = $scores[0]->text();
	if (@scores > 1)  {
	    print STDERR "analysis XML file (url=$url) contains more than 1 score element\n";
	}
	if ($score !~ /\d+/)  {
	    print STDERR "analysis XML (url=$url) score, '$score' is not numeric\n";
	}  elsif ($score < 0 or $score > 100)  {
	    print STDERR "analysis XML (url=$url) score, '$score' is not 0-100\n";
	}
    }  else  {
	print STDERR "analysis XML file (url=$url) contain no score element\n";
    }

    my $file = $url;
    $file =~ s/^\/?(.*?)(\?.*)?$/$1/;

    my $r = { file => $file, score => $score };
    push @warningData, $r;

    $tree->purge();
}


sub GetFileDetails
{
    my ($tree, $elem) = @_;
    $line      = $elem->att('line_number');
    $bugGroup   = $elem->att('significance');
    $bugCode   = $elem->att('warningclass');
    $filename = $elem->att('filename');
    $method = $elem->att('procedure');
    $tree->purge();
}


sub GetCWEDetails
{
    my ($tree, $elem) = @_;

    foreach my $cwe ($elem->children('category'))  {
	push(@weaknessCategories, $cwe->text);
    }
    $tree->purge();
}


sub GetListingDetails
{
    my ($tree, $elem) = @_;

    foreach my $procedure ($elem->children)  {
	ProcedureDetails($procedure, "");
    }
    $tree->purge();
}


sub ProcedureDetails
{
    my ($procedure, $filename) = @_;

    my $procedure_name = $procedure->att('name');
    if (defined $procedure->first_child('file'))  {
	$filename = $procedure->first_child('file')->att('name');
    }
    foreach my $line ($procedure->children('line'))  {
	LineDetails($line, $procedure_name, $filename);
    }
}


sub LineDetails
{
    my ($line, $procedure_name, $filename) = @_;

    my $lineNum       = $line->att('number');
    my $message;

    foreach my $inner ($line->children)  {
	if ($inner->gi eq 'msg')  {
	    msg_format_star($inner);
	    msg_format($inner);
	    my $message = msg_details($inner);
	    $message =~ s/^\n*//;
	    $eventNum = $inner->att("msg_id");
	    $buglocation_hash{$eventNum} = $filename . ":" . $lineNum . ":" . $message;
	    # $bugMsg = "$bugMsg Event $eventNum at $filename:$lineNum: $message\n\n";
	}  else  {
	    InnerDetails($inner, $filename);
	}
    }
}


sub InnerDetails
{
    my ($miscDetails, $filename) = @_;

    if ($miscDetails->gi eq 'procedure')  {
	ProcedureDetails($miscDetails, $filename);
    }  else  {
	foreach my $inner ($miscDetails->children)  {
	    InnerDetails($inner, $filename);
	}
    }
}


sub msg_format_star
{
    my ($msg) = @_;

    my @list;

    @list = $msg->descendants;
    foreach my $elem (@list)  {
	if ($elem->gi eq 'li')  {
	    $elem->prefix("* ");
	}
    }
}


sub msg_format
{
    my ($msg) = @_;

    my @list;
    foreach my $msg_child ($msg->children)  {
	if ($msg_child->gi eq 'ul')  {
	    @list = $msg_child->descendants;
	    foreach my $elem (@list)  {
		if ($elem->gi eq "li")  {
		    $elem->prefix("   ");
		}
	    }
	}
	msg_format($msg_child);
    }

    return;
}


sub msg_details
{
    my ($msg) = @_;

    my $message = $msg->sprint();
    $message =~ s/\<li\>/\n/g;
    $message =~ s/\<link msg="m(.*?)"\>(.*?)\<\/link\>/ [event $1, $2]/g;
    $message =~ s/\<paragraph\>/\n/g;
    $message =~ s/\<link msg="m(.*?)"\>/[event $1] /g;
    $message =~ s/\<.*?\>//g;
    $message =~ s/,\s*]/]/g;
    $message =~ s/&lt;/\</g;
    $message =~ s/&amp;/&/g;
    $message =~ s/&gt;/>/g;
    $message =~ s/&quot;/"/g;
    $message =~ s/&apos;/'/g;
    return $message;
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
