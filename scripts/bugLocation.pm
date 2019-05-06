#!/usr/bin/perl -w
package bugLocation;

use strict;


sub new
{
    my $class = shift;
    my $self= {
		_bugLocationId => shift,
		_bugClassname => shift,
		_sourceFile => shift,
		_startLine => shift,
		_endLine => shift,
		_beginColumn => shift,
		_endColumn => shift,
		_bugMessage => shift,
		_primary => shift,
		noAdjustPath => shift,
	      };
    bless $self, $class;
    return $self;
}


sub setBugColumn
{
    my ($self, $start_column, $end_column) = @_;
    $self->{_beginColumn} = $start_column if defined $start_column;
    $self->{_endColumn} = $end_column if defined $end_column;
}


sub printXML
{
    my ($self, $writer, $classStartLine, $classEndLine, $forcePrimary) = @_;
    my ($start, $end);

    $self->{_endLine} = $self->{_startLine} if !defined $self->{_endLine};

    if (defined $self->{_startLine} && defined $self->{_endLine}
	    && $self->{_startLine} ne "" && $self->{_endLine} ne "")  {
	$start = $self->{_startLine};
	$end = $self->{_endLine};
    }  else  {
	$start = $classStartLine;
	$end = $classEndLine;
    }

    my $primary = $self->{_primary};
    $primary = 'true' if $forcePrimary;
    $writer->startTag('Location', 'id' => $self->{_bugLocationId}, 'primary' => $primary);

    $writer->startTag('SourceFile');
    $writer->characters($self->{_sourceFile}) if defined $self->{_sourceFile};
    $writer->endTag();

    if (defined $start and $start > 0)  {
	$writer->startTag('StartLine');
	$writer->characters($start);	
	$writer->endTag();
    }

    if (defined $end and $end > 0)  {
	$writer->startTag('EndLine');
	$writer->characters($end);
	$writer->endTag();
    }

    if (defined $self->{_beginColumn} and $self->{_beginColumn} > 0)  {
	$writer->startTag('StartColumn');
	$writer->characters($self->{_beginColumn});
	$writer->endTag();
    }

    if (defined $self->{_endColumn} and $self->{_endColumn} > 0)  {
	$writer->startTag('EndColumn');
	$writer->characters($self->{_endColumn});
	$writer->endTag();
    }

    if (defined $self->{_bugMessage} and $self->{_bugMessage} ne "")  {
	$writer->startTag('Explanation');
	$writer->characters($self->{_bugMessage});
	$writer->endTag();
    }

    $writer->endTag();
}


1;
