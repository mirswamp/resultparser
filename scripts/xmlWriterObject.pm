#!/usr/bin/perl -w
package xmlWriterObject;
use strict;
use XML::Writer;
use IO qw(File);


sub new
{
    my ($class, $outputFile) = @_;

    $class = ref $class if ref $class;

    my $output = new IO::File(">$outputFile");
    my $writer = new XML::Writer(OUTPUT => $output, DATA_MODE => 'true', DATA_INDENT => 2, ENCODING => 'utf-8');
    my $self = {
	    output		=> $output,
	    writer		=> $writer,
	    metricCounts	=> {},
	    metricSums		=> {},
	    metricSumOfSquares	=> {},
	    metricMinValues	=> {},
	    metricMaxValues	=> {},
	    bugId		=> 1,
	    metricId		=> 0,
	    };

    bless $self, $class;

    return $self;
}


sub getOutputFileReference
{
    my ($self) = @_;

    return $self->{output};
}


sub getWriter
{
    my ($self) = @_;

    return $self->{writer};
}


sub addStartTag
{
    my ($self, $toolName, $toolVersion, $uuid) = @_;

    my $writer = $self->getWriter();

    ## This adds an XML Declaration to say that the output is UTF-8
    ## compliant.    It's a different thing than generating UTF-8.
    ## W/out this there is no XML declaration in the output document.
    $writer->xmlDecl('UTF-8');

    my %attrs = (
	    'tool_name'		=> "$toolName",
	    'tool_version'	=> "$toolVersion",
	    'uuid'		=> "$uuid"
	    );
    $writer->startTag('AnalyzerReport', %attrs);
}


sub addEndTag
{
    my ($self) = @_;

    my $writer = $self->getWriter();

    $writer->endTag();
}


sub writeBugObject
{
    my ($self, $bug) = @_;

    my $writer = $self->getWriter();

    my $byte_count = 0;
    my $initial_byte_count = 0;
    my $output = $self->getOutputFileReference();
    my $final_byte_count = tell($output);
    $initial_byte_count = $final_byte_count;

    $bug->printXML($writer);

    $final_byte_count = tell($output);
    $byte_count = $final_byte_count - $initial_byte_count;

    my $code = $bug->getBugCode();
    my $group = $bug->getBugGroup();
    my $tag;

    ++$self->{summary}{$group}{$code}{count};
    $self->{summary}{$group}{$code}{bytes} += $byte_count;;

    $self->{bugId}++;
    undef $bug if defined $bug;
}


sub writeMetricObjectUtil
{
    my ($self, $metrics) = @_;

    foreach my $file (keys %$metrics)  {
	foreach my $type (keys %{$metrics->{$file}})  {
	    if ($type eq "func-stat")  {
		foreach my $function (keys %{$metrics->{$file}{$type}})  {
		    $self->writeMetricObject($metrics->{$file}{$type}{$function})
		}
	    }  elsif ($type eq 'file-stat')  {
		$self->writeMetricObject($metrics->{$file}{$type});
	    }  else  {
		die "unknown type '$type' for metric for file '$file'";
	    }
	}
    }
}


sub writeMetricObject
{
    my ($self, $metric) = @_;

    my $writer = $self->getWriter();

    my $filename = $metric->{"file"};
    my $functionName = "";
    my $class = "";
    if (exists $metric->{"function"})  {
	$functionName = $metric->{"function"};
    }
    if (exists $metric->{"class"})  {
	$class = $metric->{"class"};
    }
    my $metrics;
    if (exists $metric->{"metrics"})  {
	$metrics = $metric->{"metrics"};
    }  else  {
	return;
    }

    foreach my $type (keys %$metrics)  {
	if ($type !~ /^((blank|total|comment|code)-lines|language|ccn|params|token)$/)  {
	    die "unknown metric type '$type'";
	}
	
	++$self->{metricId};
	$writer->startTag('Metric', 'id' => $self->{metricId});

	$writer->startTag('Location');
	$writer->startTag('SourceFile');
	#$writer->characters($metric->{'SourceFile'});
	$writer->characters($filename);
	$writer->endTag();
	$writer->endTag();

	if ($class ne "")  {
	    $writer->startTag('Class');
	    $writer->characters($class);
	    $writer->endTag();
	}

	if ($functionName ne "")  {
	    $writer->startTag('Method');
	    $writer->characters($functionName);
	    $writer->endTag();
	}
	$writer->startTag('Type');
	$writer->characters($type);
	$writer->endTag();

	my $value = $metrics->{$type};
	$writer->startTag('Value');
	$writer->characters($value);
	$writer->endTag();

	$writer->endTag();

	if ($type ne "language" and exists $self->{metricCounts}{$type})  {
	    $self->{metricSums}{$type} += $value;
	    $self->{metricCounts}{$type} += 1;
	    $self->{metricSumOfSquares}{$type} += $value * $value;
	    if ($self->{metricMaxValues}{$type} < $value)  {
		$self->{metricMaxValues}{$type} = $value;
	    }  elsif ($self->{metricMinValues}{$type} > $value)  {
		$self->{metricMinValues}{$type} = $value;
	    }
	}  elsif ($type ne "language")  {
	    $self->{metricSums}{$type} = $value;
	    $self->{metricCounts}{$type} = 1;
	    $self->{metricSumOfSquares}{$type} = $value * $value;
	    $self->{metricMaxValues}{$type} = $value;
	    $self->{metricMinValues}{$type} = $value;
	}
    }
}


sub getBugId
{
    my ($self) = @_;

    return $self->{bugId};
}


sub writeSummary
{
    my ($self) = @_;

    my $writer = $self->getWriter();

    if ($self->{summary})  {
	$writer->startTag('BugSummary');
	foreach my $group (sort keys %{$self->{summary}})  {
	    foreach my $code (sort keys ${$self->{summary{$group}}})  {
		my $data = $self->{summary}{$group}{$code};
		$writer->emptyTag('BugCategory', 'group' => "$group", 'code' => "$code",
			'count' => $data->{count}, 'bytes' => $data->{bytes});
	    }
	}
	$writer->endTag();
    }

    if (%{$self->{metricCounts}})  {
	$writer->startTag('MetricSummaries');
	foreach my $summary (keys %{$self->{metricCounts}})  {
	    $writer->startTag('MetricSummary');

	    $writer->startTag('Type');
	    $writer->characters($summary);
	    $writer->endTag();

	    $writer->startTag('Count');
	    $writer->characters($self->{metricCounts}{$summary});
	    $writer->endTag();

	    $writer->startTag('Sum');
	    $writer->characters($self->{metricSums}{$summary});
	    $writer->endTag();

	    $writer->startTag('SumOfSquares');
	    $writer->characters($self->{metricSumOfSquares}{$summary});
	    $writer->endTag();

	    $writer->startTag('Minimum');
	    $writer->characters($self->{metricMinValues}{$summary});
	    $writer->endTag();

	    $writer->startTag('Maximum');
	    $writer->characters($self->{metricMaxValues}{$summary});
	    $writer->endTag();

	    $writer->startTag('Average');
	    my $count = $self->{metricCounts}{$summary};
	    my $avg = 0;
	    if ($count != 0)  {
		$avg = $self->{metricSums}{$summary}/$count;
	    }
	    $writer->characters(sprintf("%.2f", $avg));
	    $writer->endTag();

	    my $square_of_sum = $self->{metricSums}{$summary} * $self->{metricSums}{$summary};
	    my $denominator = ($self->{metricCounts}{$summary} * $self->{metricCounts}{$summary}-1);
	    my $stddev = 0;
	    if ($denominator != 0)  {
		$stddev = sqrt(($self->{metricSumOfSquares}{$summary}
			* $self->{metricCounts}{$summary} - $square_of_sum) / $denominator);
	    }
	    $writer->startTag('StandardDeviation');
	    $writer->characters(sprintf("%.2f", $stddev));
	    $writer->endTag();

	    $writer->endTag();
	}
	$writer->endTag();
    }
}


1;
