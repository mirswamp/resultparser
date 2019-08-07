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


# dispatch any methods not defined to the objects
# return the value of the last object called
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


# delete the child objects so they are DESTROYed
sub DESTROY
{
    my $self = shift;

    $self->{objs} = ();
}


1;
