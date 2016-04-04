#!/usr/bin/perl
package xmlWriterObject;
use XML::Writer;
use IO qw(File);

my %byteCountHash;
my %count_hash;
my $bugId;

sub new
{
        my ($self, $output_file)=@_;
        $self->{_output} = new IO::File(">$output_file" );
        $self->{_writer}=new XML::Writer(OUTPUT => $self->{_output}, DATA_MODE=>'true', DATA_INDENT=>2, ENCODING => 'utf-8' );
        $bugId = 1;
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
    #print "Done writing bug object".$bugId;
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
	$self->{_writer}->startTag('BugSummary' ) ;
	if(%count_hash)
	{       
        foreach my $object (keys(%count_hash ) )
        {
            my ($code,$group ) = split ('~#~' ,$object );
            $self->{_writer}->emptyTag('BugCategory', 'group'=>"$group", 'code'=>"$code", 'count'=>$count_hash{$object }, 'bytes'=> $byteCountHash{$object});
        }
                
	}
	        $self->{_writer}->endTag();
}
1;