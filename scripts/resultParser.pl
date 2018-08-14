#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin";
use Parser;
use Util;
use File::Spec;
#use Memory::Usage;

#my $mu = Memory::Usage->new();
#$mu->record('Before XML Parsing');

#$mu->record('After XML parsing');
#$mu->dump();


sub ExecParser
{
    my ($toolName, @args) = @_;

    my $toolScript = File::Spec->catfile($FindBin::Bin, "$toolName.pl");
    my $perlPath = $^X;

    my @execString = ($perlPath, $toolScript, @args);
    print STDERR "\n", join(' ', @execString), "\n\n";
    exec {$perlPath} @execString or die "failed to exec @execString: $!";
}


sub main
{
    my @savedArgv = @ARGV;

    my $options = Parser::ProcessOptions();

    my $toolName = $options->{tool_name};

    $toolName = Parser::GetToolName($options->{summary_file});

    ExecParser($toolName, @savedArgv);

    die "ExecParser failed for $toolName";
}

main();
