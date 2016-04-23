#!/usr/bin/perl
package xmlWriterObject;
use XML::Writer;
use IO qw(File);

my %byteCountHash;
my %count_hash;
my $metricId;
my %metric_count_hash;
my %metricValueSummationHash;
my %metricSquareOfValuesHash;
my %metricMinValueHash;
my %metricMaxValueHash;
my $bugId;

sub new
{
        my ($self, $output_file)=@_;
        $self->{_output} = new IO::File(">$output_file" );
        $self->{_writer}=new XML::Writer(OUTPUT => $self->{_output}, DATA_MODE=>'true', DATA_INDENT=>2, ENCODING => 'utf-8' );
        $bugId = 1;
        $metricId = 0;
        return $self;
}

sub addStartTag
{
	    my ($self, $tool_name, $tool_version, $uuid)=@_;
	    
		## This adds an XML Declaration to say that the output is UTF-8
	    ## compliant.    It's a different thing than generating UTF-8.
	    ## W/out this there is no XML declaration in the output document.
        $self->{_writer}->xmlDecl('UTF-8' );
        $self->{_writer}->startTag('AnalyzerReport' ,'tool_name' => "$tool_name" ,'tool_version' => "$tool_version" ,'uuid'=> "$uuid" );
}

sub addEndTag
{
	my ($self)=@_;
	$self->{_writer}->endTag();
}

sub getWriter
{
	my ($self)=@_;
	return $self->{_writer};
}

sub writeBugObject
{
	my ($self, $bugObject) = @_;
	my $byte_count = 0;
    my $initial_byte_count = 0;
    my $final_byte_count = tell($self->{_output});
    $initial_byte_count = $final_byte_count;
    
	$bugObject->printXML($self->{_writer});
	
	$final_byte_count = tell($self->{_output});
    $byte_count = $final_byte_count - $initial_byte_count;
    
    my $code = $bugObject->getBugCode();
    my $group = $bugObject->getBugGroup();
    my $tag;
    
    if ($code ne "" ) 
    {
        $tag = $code;
    }
    else 
    {
        $tag = "undefined";
    }
    
    if ($group ne "" ) 
    {
        $tag = $tag."~#~".$group; 
    }
    else 
    {
        $tag = $tag."~#~"."undefined"; 
    }

    if (!(defined $tag) )
    {
        die ("bug group and bug code doesnot exist for grouping the bugs" );
    }
    else
    {
        if (exists $count_hash{$tag } ) 
        {
            $count_hash{$tag}++;
        }
        else
        {
            $count_hash{$tag }  = 1; 
        }
        if (exists $byteCountHash{$tag})
        {
            $byteCountHash{$tag} = $byteCountHash{$tag} + $byte_count;
        }
        else
        {
            $byteCountHash{$tag} = $byte_count;
        }
    }
    $bugId++;
    undef $bugObject if defined $bugObject;
}

sub writeMetricObjectUtil
{
	my ($self, %metricInstanceHash) = @_;
	foreach my $object (keys(%metricInstanceHash))
    {
        foreach my $fnName (keys(%{$metricInstanceHash{$object}})){
            if($fnName eq "func-stat"){
                foreach my $function (keys(%{$metricInstanceHash{$object}{$fnName}})){
                    writeMetricObject($self,\%{$metricInstanceHash{$object}{$fnName}{$function}})
                }
            }else{
                writeMetricObject($self,\%{$metricInstanceHash{$object}{$fnName}});
            }
        }
    }
}

sub writeMetricObject
{
    my($self, $metricInstance) = @_;
    my $file_name = ${$metricInstance}{"file"};
    my $function_name = "";
    my $class = "";
    if(exists ${$metricInstance}{"function"}){
        $function_name = ${$metricInstance}{"function"};
    }
    if(exists ${$metricInstance}{"class"}){
        $class = ${$metricInstance}{"class"};
    }
    my $metricHash;
    if(exists ${$metricInstance}{"metrics"}){
        $metricHash = ${$metricInstance}{"metrics"};
    }
    else{
        return;
    }

    foreach my $name (keys (%{$metricHash})){
        if($name eq "location" or $name eq "file"){

        }else{
            $metricId++;
            $self->{_writer}->startTag('Metric','id'=>$metricId);

            $self->{_writer}->startTag('Location');
            $self->{_writer}->startTag('SourceFile');
            #$self->{_writer}->characters(${$metricInstance}{'SourceFile'});
            $self->{_writer}->characters($file_name);
            $self->{_writer}->endTag();
            $self->{_writer}->endTag();

            if($class ne ""){
                $self->{_writer}->startTag('Class');
                $self->{_writer}->characters($class);
                $self->{_writer}->endTag();
            }

            if(exists ${$metricHash}{'function'}){
                $self->{_writer}->startTag('Method');
                $self->{_writer}->characters(${$metricHash}{'method'});
                $self->{_writer}->endTag();
            }elsif($function_name ne ""){
                $self->{_writer}->startTag('Method');
                $self->{_writer}->characters($function_name);
                $self->{_writer}->endTag();
            }
            $self->{_writer}->startTag('Type');
            $self->{_writer}->characters($name);
            $self->{_writer}->endTag();
            $self->{_writer}->startTag('Value');
            $self->{_writer}->characters(${$metricHash}{$name});
            $self->{_writer}->endTag();
            $self->{_writer}->endTag();
            if($name ne "language" and exists $metric_count_hash{$name}){
                $metricValueSummationHash{$name}+=${$metricHash}{$name};
                $metric_count_hash{$name}+=1;
                $metricSquareOfValuesHash{$name}+=${$metricHash}{$name}*${$metricHash}{$name};
                if($metricMaxValueHash{$name}<${$metricHash}{$name}){
                    $metricMaxValueHash{$name} = ${$metricHash}{$name};
                }elsif($metricMinValueHash{$name}>${$metricHash}{$name}){
                    $metricMinValueHash{$name} = ${$metricHash}{$name};
                }
            }elsif($name ne "language"){
                $metricValueSummationHash{$name} = ${$metricHash}{$name};
                $metric_count_hash{$name}=1;
                $x = ${$metricHash}{$name};
                $metricSquareOfValuesHash{$name} = $x*$x;
                $metricMaxValueHash{$name} = ${$metricHash}{$name};
                $metricMinValueHash{$name} = ${$metricHash}{$name};
            }
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
	return $bugId;
}

sub writeSummary
{
	my ($self) = @_;
	if(%count_hash)
	{       
		$self->{_writer}->startTag('BugSummary' ) ;
        foreach my $object (keys(%count_hash ) )
        {
            my ($code,$group ) = split ('~#~' ,$object );
            $self->{_writer}->emptyTag('BugCategory', 'group'=>"$group", 'code'=>"$code", 'count'=>$count_hash{$object }, 'bytes'=> $byteCountHash{$object});
        }
                
	}
	if(%metric_count_hash)
    {       
        $self->{_writer}->startTag('MetricSummaries');
        foreach my $summary (keys(%metric_count_hash)){
            $self->{_writer}->startTag('MetricSummary');

            $self->{_writer}->startTag('Type');
            $self->{_writer}->characters($summary);
            $self->{_writer}->endTag();

            $self->{_writer}->startTag('Count');
            $self->{_writer}->characters($metric_count_hash{$summary});
            $self->{_writer}->endTag();

            $self->{_writer}->startTag('Sum');
            $self->{_writer}->characters($metricValueSummationHash{$summary});
            $self->{_writer}->endTag();

            $self->{_writer}->startTag('SumOfSquares');
            $self->{_writer}->characters($metricSquareOfValuesHash{$summary});
            $self->{_writer}->endTag();

            $self->{_writer}->startTag('Minimum');
            $self->{_writer}->characters($metricMinValueHash{$summary});
            $self->{_writer}->endTag();

            $self->{_writer}->startTag('Maximum');
            $self->{_writer}->characters($metricMaxValueHash{$summary});
            $self->{_writer}->endTag();

            $self->{_writer}->startTag('Average');
            my $count = $metric_count_hash{$summary};
            my $avg = 0;
            if($count!=0){
                $avg = $metricValueSummationHash{$summary}/$count;
            }
            $self->{_writer}->characters(sprintf("%.2f",$avg));
            $self->{_writer}->endTag();

            my $square_of_sum = $metricValueSummationHash{$summary}*$metricValueSummationHash{$summary};
            my $denominator = ($metric_count_hash{$summary}*$metric_count_hash{$summary}-1);
            my $stddev = 0;
            if($denominator != 0){
                $stddev = sqrt(($metricSquareOfValuesHash{$summary}*$metric_count_hash{$summary} - $square_of_sum)/$denominator);
            }
            $self->{_writer}->startTag('StandardDeviation');
            $self->{_writer}->characters(sprintf("%.2f",$stddev));
            $self->{_writer}->endTag();

            $self->{_writer}->endTag();
        }
                
    }
    $self->{_writer}->endTag();
}
1;