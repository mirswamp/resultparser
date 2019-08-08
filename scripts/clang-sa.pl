#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $indexCheckFlag = 1;
    if (!-f "$fn/index.html")  {
	$indexCheckFlag = 0;
    }
    opendir(DIR, $fn) or die "opendir $fn: $!";
    my @filelist = grep
		    {-f "$fn/$_" && $_ ne "index.html" && $_ =~ m/\.html$/}
		    readdir(DIR);

    close(DIR);
    my $file_count = scalar(@filelist);
    die "ERROR:  Clang assessment run did not complete, missing index.html file"
	    if ($file_count > 0 and $indexCheckFlag eq 0);
    foreach my $file (@filelist)  {
	my $in_file1 = new IO::File("<$fn/$file") or die "open $fn/$file: $!";
	my @lines = grep /<!--.*BUG.*-->/, <$in_file1>;
	close($in_file1);
	my $in_file2 = new IO::File("<$fn/$file") or die "open $fn/$file: $!";
	my @column = grep /class=\"rowname\".*Location.*line/, <$in_file2>;
	close($in_file2);

	my ($BUGFILE, $BUGDESC, $BUGTYPE, $BUGCATEGORY, $BUGLINE, $BUGCOLUMN, $BUGPATHLENGTH);
	foreach my $line (@lines)  {
	    if ($line =~ m/.*BUGFILE/)  {
		$BUGFILE = bugLine($line);
	    }  elsif ($line =~ m/.*BUGDESC/)  {
		$BUGDESC = bugLine($line);
	    }  elsif ($line =~ m/.*BUGTYPE/)  {
		$BUGTYPE = bugLine($line);
	    }  elsif ($line =~ m/.*BUGCATEGORY/)  {
		$BUGCATEGORY = bugLine($line);
	    }  elsif ($line =~ m/.*BUGLINE/)  {
		$BUGLINE = bugLine($line);
	    }  elsif ($line =~ m/.*BUGPATHLENGTH/)  {
		$BUGPATHLENGTH = bugLine($line);
	    }
	}
	foreach my $line (@column)  {
	    if ($line =~ m/.*line.*column *\d.*/)  {
		$BUGCOLUMN = &bugColumn($line);
	    }
	}
	my $bug = $parser->NewBugInstance();
	$bug->setBugMessage($BUGDESC);
	$bug->setBugCode($BUGTYPE);
	$bug->setBugGroup($BUGCATEGORY);
	$bug->setBugLocation(
	    1, "", $BUGFILE, $BUGLINE, $BUGLINE, $BUGCOLUMN,
	    "0", "", "true", "true"
	);
	$bug->setBugPathLength($BUGPATHLENGTH);
	$parser->WriteBugObject($bug);
    }
}


sub bugLine
{
    my ($line) = @_;

    $line =~ s/(<!--)//;
    $line =~ s/-->//;
    $line =~ s/^ *//;
    my ($val1, $val2) = split /\s *\s*/, $line, 2;
    $val2 =~ s/(\n|\r)$//;
    $val2 =~ s/ *$//;
    return ($val2);
}


sub bugColumn {
    my ($line) = @_;

    $line =~ s/^.*> *line *(\d)* *, *column *//;
    $line =~ s/<.*>$//;
    $line =~ s/(\n|\r)$//;
    $line =~ s/ *$//;
    return ($line);
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
