#!/usr/bin/perl -w

use strict;

package MultiobjectDispatcher;

sub new
{
    my $invocant = shift;

    my $class = ref($invocant) || $invocant;

    my $self = {
	objs => [ @_ ],
    };

    return bless $self, $class;
}


sub AddNewObject
{
    my $self = shift;

    push @{$self->{objs}}, @_;
}



sub AUTOLOAD
{
    my $self = shift;

    my $method = our $AUTOLOAD;

    $method =~ s/.*:://;

    my $r;
    foreach my $o (@{$self->{objs}})  {
	$r = $o->$method(@_);
    }

    return $r
}


1;
