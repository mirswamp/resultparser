#!/usr/bin/perl
package bugMethod;

sub new
{
    my $class=shift;
    my $self= {
		    _methodId=>shift,
		    _methodName=>shift,
		    _className=>shift,
		    _primary=>shift
	      };
    bless $self,$class;
    return $self;
}

sub printBugMethod
{
    my ($self)=@_;
    return $self->{_methodId} . " :: " . $self->{_className} . " :: " . $self->{_methodName} . " :: " . $self->{_primary};
}

sub printXML
{
    my ($self,$writer)=@_;

    $writer->startTag('Method','id'=>$self->{_methodId}, 'primary'=>$self->{_primary});
    $writer->characters($self->{_methodName});
    $writer->endTag();
}

1;

