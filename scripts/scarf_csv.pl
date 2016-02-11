#! /usr/bin/perl

use strict;
use Twig;
use Data::Dumper;
use Getopt::Long;
use Switch;

my $infile = $ARGV[0];
my $outfile = $ARGV[1];

open CSVFILE, ">$outfile" or die "open $outfile: $!";
my $open_line =  CreateCsvLine ("BugInstanceId", "SourceFile", "StartLine", "EndLine", "Method", "BugCode", "BugMessage", "BugGroup");
print CSVFILE $open_line;
my $xpath = "BugInstance";
my $twig = new XML::Twig(keep_encoding => 1, TwigHandlers => {
                                        $xpath => \&parse_routine
                                           });

$twig->parsefile($infile);


sub parse_routine {
  my ($tree,$elem) = @_;
  my $id = $elem->{'att'}->{id};
  my @locations = $elem->first_child('BugLocations')->children;
  my ($source_file,$start_line,$end_line,$location,$method,$bugcode,$bugmessage,$buggroup);
  foreach  $location (@locations) {
      if ($location->{'att'}->{primary} eq "true"){
           $source_file = $location->first_child('SourceFile')->field if ($location->first_child('SourceFile') != 0);
           $start_line = $location->first_child('StartLine')->field if ( $location->first_child('StartLine') != 0);
           $end_line = $location->first_child('EndLine')->field if ($location->first_child('EndLine') != 0) ;
           last;
      } ;
      
  }
  # my $start_column = "NA";
  # $start_column = $location->first_child('StartColumn')->field if ($location->first_child('StartColumn') != 0);
  # my $end_column = "NA";
  # $end_column = $location->first_child('EndColumn')->field if ($location->first_child('EndColumn') != 0);
  my @methods = $elem->first_child('Methods')->children;
  foreach my $method_elem (@methods)
  {
    $method = $method_elem->field  if ($elem->first_child('Methods') != 0);
  }
  $bugcode = $elem->first_child('BugCode')->field if ($elem->first_child('BugCode') != 0);
  $bugmessage = $elem->first_child('BugMessage')->field if ($elem->first_child('BugMessage') != 0);
  $buggroup = $elem->first_child('BugGroup')->field if ($elem->first_child('BugGroup') != 0);
  my $line = CreateCsvLine ($id,$source_file,$start_line,$end_line,$method,$bugcode,$bugmessage,$buggroup);
  print CSVFILE $line;
  $tree->purge;
}


sub CreateCsvLine
{
     my $line = join(',', map {CreateCsvElement($_)} @_)."\n";
     return $line;
}


sub CreateCsvElement
{
     my $v = shift;
     $v = '' unless defined $v;
     $v =~ s/"/""/g;
     $v = "\"$v\"" if $v =~ /\W/;
     return $v;
}

