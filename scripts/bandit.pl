#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $toolVersion = $parser->{ps}{tool_version};

    if ($toolVersion ne "8ba3536")  {
	ParseJson($parser, $fn);
    }  else  {
	# The 8ba3536 version of bandit had a different file format

	my ($bugCode, $bugMsg, $lineNum, $filePath);

	my $startBug = 0;
	open(my $fh, "<", $fn) or die "open $fn: $!";
	while (<$fh>)  {
	    my $line = $_;
	    chomp($line);
	    if ($line =~ /Test results:/)  {
		$startBug = 1;
		next;
	    }
	    next if ($startBug == 0);
	    my $firstLineSeen = 0;
	    if ($line =~ /^\>\>/)  {
		if ($firstLineSeen > 0)  {
		    my $bug = $parser->NewBugInstance();
		    $bug->setBugLocation(1, "", $filePath, $lineNum, $lineNum,
			    "", "", "", 'true', 'true');
		    $bug->setBugCode($bugCode);
		    $bug->setBugMessage($bugMsg);
		    $parser->WriteBugObject($bug);
		    undef $bugCode;
		    undef $bugMsg;
		    undef $filePath;
		    undef $lineNum;
		}
		$firstLineSeen = 1;
		$line =~ s/^\>\>//;
		$bugCode = $line;
		$bugMsg  = $line;
	    }  else  {
		my @tokens = split("::", $line);
		if ($#tokens == 1)  {
		    $tokens[0] =~ s/^ - //;
		    $filePath = $tokens[0];
		    $lineNum = $tokens[1];
		}
	    }
	}
	$fh->close();
    }
}


sub GetBanditBugObjectFromJson
{
    my ($parser, $warning) = @_;

    my $bug = $parser->NewBugInstance();
    $bug->setBugCode($warning->{test_name});
    $bug->setBugMessage($warning->{issue_text});
    $bug->setBugSeverity($warning->{issue_severity});
    my $beginLine = $warning->{line_number};
    my $endLine;

    foreach my $number (@{$warning->{line_range}})  {
	$endLine = $number;
    }
    my $filename = $warning->{filename};
    $bug->setBugLocation(
	    1, "", $filename, $beginLine,
	    $endLine, "0", "0", "",
	    'true', 'true'
	);
    return $bug;
}


sub GetBanditErrorBugObjectFromJson
{
    my ($parser, $error) = @_;

    my $bug = $parser->NewBugInstance();
    my $filename = $error->{filename};
    my $reason = $error->{reason};

    $bug->setBugCode('error');
    $bug->setBugMessage($reason);
    $bug->setBugSeverity('error');
    $bug->setBugLocation(
	    1, "", $filename, 0,
	    0, "0", "0", "",
	    'true', 'true'
	);

    return $bug;
}


sub ParseJson
{
    my ($parser, $fn) = @_;

    my $jsonObject = Util::ReadJsonFile($fn);

    foreach my $error (@{$jsonObject->{errors}})  {
	my $bug = GetBanditErrorBugObjectFromJson($parser, $error);
	$parser->WriteBugObject($bug);
    }

    foreach my $warning (@{$jsonObject->{results}})  {
	my $bug = GetBanditBugObjectFromJson($parser, $warning);
	$parser->WriteBugObject($bug);
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
