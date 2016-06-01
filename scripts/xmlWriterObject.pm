#!/usr/bin/perl -w
package xmlWriterObject;
use strict;
use XML::Writer;
use IO qw(File);



sub new
{
    my ($class, $outputFile) = @_;
    my $self = {};
    $class = ref $class if ref $class;

    $self->{_output} = new IO::File(">$outputFile");
    $self->{_writer}=new XML::Writer(OUTPUT => $self->{_output}, DATA_MODE => 'true', DATA_INDENT => 2, ENCODING => 'utf-8');
    $self->{byteCountHash} = {};
    $self->{bugCounts} = {};
    $self->{metricCounts} = {};
    $self->{metricSums} = {};
    $self->{metricSumOfSquares} = {};
    $self->{metricinValues} = {};
    $self->{metricMaxValues} = {};
    $self->{bugId} = 1;
    $self->{metricId} = 1;

    bless $self, $class;
    return $self;
}


sub addStartTag
{
    my ($self, $toolName, $toolVersion, $uuid) = @_;

    ## This adds an XML Declaration to say that the output is UTF-8
    ## compliant.    It's a different thing than generating UTF-8.
    ## W/out this there is no XML declaration in the output document.
    $self->{_writer}->xmlDecl('UTF-8');
    $self->{_writer}->startTag('AnalyzerReport', 'tool_name' => "$toolName",
	    'tool_version' => "$toolVersion", 'uuid'=> "$uuid");
}


sub addEndTag
{
    my ($self) = @_;
    $self->{_writer}->endTag();
}


sub getWriter
{
    my ($self) = @_;
    return $self->{_writer};
}


sub writeBugObject
{
    my ($self, $bug) = @_;
    my $byte_count = 0;
    my $initial_byte_count = 0;
    my $final_byte_count = tell($self->{_output});
    $initial_byte_count = $final_byte_count;

    $bug->printXML($self->{_writer});

    $final_byte_count = tell($self->{_output});
    $byte_count = $final_byte_count - $initial_byte_count;

    my $code = $bug->getBugCode();
    my $group = $bug->getBugGroup();
    my $tag;

    if ($code ne "")  {
	$tag = $code;
    }  else  {
	$tag = "undefined";
    }

    if ($group ne "")  {
	$tag = $tag."~#~".$group; 
    }  else  {
	$tag = $tag."~#~"."undefined"; 
    }

    if (!(defined $tag))  {
	die ("bug group and bug code doesnot exist for grouping the bugs");
    }  else  {
	if (exists $self->{bugCounts}{$tag})  {
	    $self->{bugCounts}{$tag}++;
	}  else  {
	    $self->{bugCounts}{$tag} = 1; 
	}
	if (exists $self->{byteCountHash}{$tag})  {
	    $self->{byteCountHash}{$tag} = $self->{byteCountHash}{$tag} + $byte_count;
	}  else  {
	    $self->{byteCountHash}{$tag} = $byte_count;
	}
    }
    $self->{bugId}++;
    undef $bug if defined $bug;
}


sub writeMetricObjectUtil
{
    my ($self, %metricInstanceHash) = @_;
    foreach my $object (keys(%metricInstanceHash))  {
	foreach my $fnName (keys(%{$metricInstanceHash{$object}}))  {
	    if ($fnName eq "func-stat")  {
		foreach my $function (keys(%{$metricInstanceHash{$object}{$fnName}}))  {
		    writeMetricObject($self, \%{$metricInstanceHash{$object}{$fnName}{$function}})
		}
	    }  else  {
		writeMetricObject($self, \%{$metricInstanceHash{$object}{$fnName}});
	    }
	}
    }
}


sub writeMetricObject
{
    my($self, $metricInstance) = @_;
    my $filename = ${$metricInstance}{"file"};
    my $functionName = "";
    my $class = "";
    if (exists ${$metricInstance}{"function"})  {
	$functionName = ${$metricInstance}{"function"};
    }
    if (exists ${$metricInstance}{"class"})  {
	$class = ${$metricInstance}{"class"};
    }
    my $metricHash;
    if (exists ${$metricInstance}{"metrics"})  {
	$metricHash = ${$metricInstance}{"metrics"};
    }  else  {
	return;
    }

    foreach my $name (keys (%{$metricHash}))  {
	if ($name eq "location" or $name eq "file")  {

	}  else  {
	    $self->{_writer}->startTag('Metric', 'id' => $self->{metricId});

	    $self->{_writer}->startTag('Location');
	    $self->{_writer}->startTag('SourceFile');
	    #$self->{_writer}->characters(${$metricInstance}{'SourceFile'});
	    $self->{_writer}->characters($filename);
	    $self->{_writer}->endTag();
	    $self->{_writer}->endTag();

	    if ($class ne "")  {
		$self->{_writer}->startTag('Class');
		$self->{_writer}->characters($class);
		$self->{_writer}->endTag();
	    }

	    if (exists ${$metricHash}{'function'})  {
		$self->{_writer}->startTag('Method');
		$self->{_writer}->characters(${$metricHash}{'method'});
		$self->{_writer}->endTag();
	    }  elsif ($functionName ne "")  {
		$self->{_writer}->startTag('Method');
		$self->{_writer}->characters($functionName);
		$self->{_writer}->endTag();
	    }
	    $self->{_writer}->startTag('Type');
	    $self->{_writer}->characters($name);
	    $self->{_writer}->endTag();
	    $self->{_writer}->startTag('Value');
	    $self->{_writer}->characters(${$metricHash}{$name});
	    $self->{_writer}->endTag();
	    $self->{_writer}->endTag();
	    if ($name ne "language" and exists $self->{metricCounts}{$name})  {
		$self->{metricSums}{$name} += ${$metricHash}{$name};
		$self->{metricCounts}{$name} += 1;
		$self->{metricSumOfSquares}{$name} += ${$metricHash}{$name}*${$metricHash}{$name};
		if ($self->{metricMaxValues}{$name}<${$metricHash}{$name})  {
		    $self->{metricMaxValues}{$name} = ${$metricHash}{$name};
		}  elsif ($self->{metricinValues}{$name}>${$metricHash}{$name})  {
		    $self->{metricinValues}{$name} = ${$metricHash}{$name};
		}
	    }  elsif ($name ne "language")  {
		$self->{metricSums}{$name} = ${$metricHash}{$name};
		$self->{metricCounts}{$name} = 1;
		my $x = ${$metricHash}{$name};
		$self->{metricSumOfSquares}{$name} = $x * $x;
		$self->{metricMaxValues}{$name} = ${$metricHash}{$name};
		$self->{metricinValues}{$name} = ${$metricHash}{$name};
	    }
	    $self->{metricId}++;
	}
    }
}


sub getOutputFileReference
{
    my ($self) = @_;
    return $self->{_output};
}


sub getBugId
{
    my ($self) = @_;
    return $self->{bugId};
}


sub writeSummary
{
    my ($self) = @_;
    if (%{$self->{bugCounts}})  {
	$self->{_writer}->startTag('BugSummary') ;
	foreach my $object (keys %{$self->{bugCounts}})  {
	    my ($code, $group) = split ('~#~', $object);
	    $self->{_writer}->emptyTag('BugCategory', 'group' => "$group", 'code' => "$code",
		    'count' => $self->{bugCounts}{$object},
		    'bytes' => $self->{byteCountHash}{$object});
	}
	$self->{_writer}->endTag();
    }
    if (%{$self->{metricCounts}})  {
	$self->{_writer}->startTag('MetricSummaries');
	foreach my $summary (keys %{$self->{metricCounts}})  {
	    $self->{_writer}->startTag('MetricSummary');

	    $self->{_writer}->startTag('Type');
	    $self->{_writer}->characters($summary);
	    $self->{_writer}->endTag();

	    $self->{_writer}->startTag('Count');
	    $self->{_writer}->characters($self->{metricCounts}{$summary});
	    $self->{_writer}->endTag();

	    $self->{_writer}->startTag('Sum');
	    $self->{_writer}->characters($self->{metricSums}{$summary});
	    $self->{_writer}->endTag();

	    $self->{_writer}->startTag('SumOfSquares');
	    $self->{_writer}->characters($self->{metricSumOfSquares}{$summary});
	    $self->{_writer}->endTag();

	    $self->{_writer}->startTag('Minimum');
	    $self->{_writer}->characters($self->{metricinValues}{$summary});
	    $self->{_writer}->endTag();

	    $self->{_writer}->startTag('Maximum');
	    $self->{_writer}->characters($self->{metricMaxValues}{$summary});
	    $self->{_writer}->endTag();

	    $self->{_writer}->startTag('Average');
	    my $count = $self->{metricCounts}{$summary};
	    my $avg = 0;
	    if ($count != 0)  {
		$avg = $self->{metricSums}{$summary}/$count;
	    }
	    $self->{_writer}->characters(sprintf("%.2f", $avg));
	    $self->{_writer}->endTag();

	    my $square_of_sum = $self->{metricSums}{$summary} * $self->{metricSums}{$summary};
	    my $denominator = ($self->{metricCounts}{$summary} * $self->{metricCounts}{$summary}-1);
	    my $stddev = 0;
	    if ($denominator != 0)  {
		$stddev = sqrt(($self->{metricSumOfSquares}{$summary}
			* $self->{metricCounts}{$summary} - $square_of_sum) / $denominator);
	    }
	    $self->{_writer}->startTag('StandardDeviation');
	    $self->{_writer}->characters(sprintf("%.2f", $stddev));
	    $self->{_writer}->endTag();

	    $self->{_writer}->endTag();
	}
	$self->{_writer}->endTag();
    }
}


1;
