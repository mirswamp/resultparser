#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use bugInstance;
use Util;

use File::Copy;


# PRQA-Framework directly produces a SCARF file and a file containing the
# weakness count, so copy the SCARF file and read the weakness count

sub ParseFile
{
    my ($parser, $fn) = @_;

    die "Only one SCARF result file permitted" unless $parser->{curAssess}{buildId} == 1;

    my $scarfOutputFn = $parser->{options}{output_file};

    copy($fn, $scarfOutputFn) or die "cp $fn $scarfOutputFn:  $!";

    my $countFn = $fn;
    $countFn =~ s/[^\/]+$/weaknesses.txt/;
    die "weaknesses count file ($countFn) not found" unless -f $countFn;

    my $count = Util::ReadFile($countFn);
    $count =~ s/\s*(.*?)\s*/$1/s;

    die "Invalid Number from count file ($countFn):  $count" unless $count =~ /\d+/ && $count >= 0;

    $parser->{weaknessCount} = $count;
}


my $parser = Parser->new(ParseFileProc => \&ParseFile, NoScarfFile => 1);
