#!/usr/bin/perl
package bugLocation;

sub new
{
    my $class=shift;
    my $self= {
		_bugLocationId=>shift,
		_bugClassname=>shift,
		_sourceFile=>shift,
		_startLineNo=>shift,
		_endLineNo=>shift,
		_beginColumn=>shift,
		_endColumn=>shift,
		_bugMessage=>shift,
		_primary=>shift
	      };
    bless $self,$class;
    return $self;
}

sub setBugColumn
{
    my ($self, $start_column, $end_column) = @_;
    $self->{_beginColumn} = $start_column if defined ($start_column);
    $self->{_endColumn} = $end_column if defined ($end_column);
}

sub printBugLocation
{
    my ($self)=@_;
	return $self->{_bugLocationId} . " :: " . $self->{_bugClassname} . " :: " . $self->{_sourceFile} . " :: " . $self->{_startLineNo} . " :: " . $self->{_endLineNo} . " :: " . $self->{_beginColumn} . " :: " . $self->{_endColumn} . " :: " . $self->{_bugMessage} . " :: " . $self->{_primary};	 
}

sub printXML
{
    my ($self,$writer,$classStartLine,$classEndLine)=@_;
    my ($start,$end);
    if	((defined ($self->{_startLineNo}) && defined ($self->{_endLineNo})) && ($self->{_startLineNo} ne "" and $self->{_endLineNo} ne ""))
    {
	$start=$self->{_startLineNo};
	$end=$self->{_endLineNo};	
    }
    else
    {
	$start=$classStartLine;
	$end=$classEndLine;
    }

    $writer->startTag('Location','id'=>$self->{_bugLocationId}, 'primary'=>$self->{_primary});

    $writer->startTag('SourceFile');
    $writer->characters($self->{_sourceFile});
    $writer->endTag();

    if (defined $start and $start > 0)
    {
	$writer->startTag('StartLine');
	$writer->characters($start);	
	$writer->endTag();
    }

    if (defined $end and $end > 0)
    {
	$writer->startTag('EndLine');
	$writer->characters($end);  
	$writer->endTag();
    }

    if (defined $self->{_beginColumn} and $self->{_beginColumn} > 0)
    {
	$writer->startTag('StartColumn');
	$writer->characters($self->{_beginColumn}); 
	$writer->endTag();
    }

    if (defined $self->{_endColumn} and $self->{_endColumn} > 0)
    {
	$writer->startTag('EndColumn');
	$writer->characters($self->{_endColumn});   
	$writer->endTag();
    }

    if (defined $self->{_bugMessage} and $self->{_bugMessage} ne "")
    {
	$writer->startTag('Explanation');
	$writer->characters($self->{_bugMessage});
	$writer->endTag();
    }
	$writer->endTag();
}

sub printXML_sate
{
    my ($self,$writer,$classStartLine,$classEndLine)=@_;
    my ($length,$start,$end);
    if	($self->{_startLineNo} ne "" and $self->{_endLineNo} ne "")
    {
#	  print $self->{_startLineNo} , $self->{_endLineNo} ,"\n";
	 $start=$self->{_startLineNo};
	 $end=$self->{_endLineNo};	
    }
    else
    {
	$start=$classStartLine;
	$end=$classEndLine;
    }
#   =$self->{_endLineNo} - $self->{_startLineNo} + 1;
    $length = $end - $start + 1 ;

	#$writer->startTag('location','id'=>$self->{_bugLocationId}, 'line'=>$self->{_startLineNo},'length'=>$length,'path'=>$self->{_sourceFile});
    $writer->startTag('location','id'=>$self->{_bugLocationId}, 'line'=>$start,'length'=>$length,'path'=>$self->{_sourceFile});
    if (defined $self->{_bugMessage})
    {
	$writer->startTag('explanation');
	$writer->characters($self->{_bugMessage});
	$writer->endTag();
    }
    $writer->endTag();
}


1;
