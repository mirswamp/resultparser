#!/usr/bin/perl -w
use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use XML::Twig;
use Util;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $metrics = {};
    my $numFile = 0;

    my $twig = XML::Twig->new(
	    twig_roots => {
		'results/files/file' => sub {
		    my ($twig, $e) = @_;
		    ++$numFile;
		    metrics($twig, $e, $metrics);
		    return 1;
		},
	    },
    );

    $twig->parsefile($fn);

    $parser->WriteMetrics($metrics);
}


sub metrics {
    my ($twig, $e, $h) = @_;

    my $root  = $twig->root;
    my @nodes = $root->descendants;
    my $line  = $twig->{twig_parser}->current_line;
    my $col   = $twig->{twig_parser}->current_column;

    my $comment    = $e->{'att'}->{'comment'};
    my $code       = $e->{'att'}->{'code'};
    my $blank      = $e->{'att'}->{'blank'};
    my $total      = $comment + $code + $blank;
    my $sourcefile = $e->{'att'}->{'name'};
    my $language   = $e->{'att'}->{'language'};
    $h->{$sourcefile}{'func-stat'}                             = {};
    $h->{$sourcefile}{'file-stat'}{'file'}                     = $sourcefile;
    $h->{$sourcefile}{'file-stat'}{'location'}{'startline'}    = "";
    $h->{$sourcefile}{'file-stat'}{'location'}{'endline'}      = "";
    $h->{$sourcefile}{'file-stat'}{'metrics'}{'code-lines'}    = $code;
    $h->{$sourcefile}{'file-stat'}{'metrics'}{'blank-lines'}   = $blank;
    $h->{$sourcefile}{'file-stat'}{'metrics'}{'comment-lines'} = $comment;
    $h->{$sourcefile}{'file-stat'}{'metrics'}{'total-lines'}   = $total;
    $h->{$sourcefile}{'file-stat'}{'metrics'}{'language'}      = $language;
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
