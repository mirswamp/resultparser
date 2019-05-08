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
    my $i = 0;

    foreach my $warning (@$jsonObject)  {
	my $jsonPath = "\$[$i]";
	++$i;

	my $bugObj = $parser->NewBugInstance();
	my $file = $warning->{filename};
	my $startLine = $warning->{start_line};
	my $endLine = $warning->{end_line};
	my $startColumn = $warning->{start_column};
	my $endColumn = $warning->{end_column};
	my $group = 'warning';
	my $code = $warning->{rule_name} . " (" . $warning->{rule_id} . ")";
	my $message = $warning->{description} . "\nMatched on " . $warning->{match};
	my $severity = $warning->{severity};

	$bugObj->setBugLocation(1, "", $file, $startLine, $endLine,
			    $startColumn, $endColumn, "", 'true', 'true');
	$bugObj->setBugMessage($message);
	$bugObj->setBugGroup($group);
	$bugObj->setBugCode($code);
	$bugObj->setBugSeverity($severity);
	$bugObj->setBugPath($jsonPath);
	$parser->WriteBugObject($bugObj);
    }
}

my $parser = Parser->new(ParseFileProc => \&ParseFile);
