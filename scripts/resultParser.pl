#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin";
use Parser;
use Util;
use File::Spec;
use Config;
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
    if ($^O !~ /mswin/i)  {
	exec {$perlPath} @execString or die "failed to exec @execString: $!";
    }  else  {
	# On Windows, use system so this driver does not return
	# before the child is done

	my $r = system {$perlPath} @execString;
	if ($r == 0)  {
	    exit 0;
	}  else  {
	    my $msg = "ERROR: system {$perlPath} @execString: failed ";
	    my $exitSignal = $r & 127;
	    if ($r == -1)  {
		$msg .= $!;
	    }  elsif ($exitSignal)  {
		my $exitSignalName = (split ' ', $Config{sig_name})[$exitSignal];
		$msg .= "killed by signal $exitSignal";
		$msg .= " (SIG$exitSignalName)" if defined $exitSignalName;
	    }  else  {
		my $exitCode = $r >> 8;
		$msg .= " exit code $exitCode";
	    }
	    die $msg;
	}
    }
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
