package ModelSEEDObject::PPOObject;
#===============================================================================
#
#         FILE:  ModelSEEDObject.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Scott Devoid (devoid@ci.uchicago.edu) 
#      COMPANY:  University of Chicago 
#      VERSION:  1.0
#      CREATED:  08/25/10 15:19:51
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
#use ModelSEEDObject;
#use AutoLoader;

sub new {
    my ($type, $object) = @_;
    my $self = {
        'object' => $object,
    };
    return bless $self; 
}

sub attr {
    my ($self, $name, $value) = @_;
    if(defined($value)) {
        $self->_object()->$name($value);        
    }
    return $self->_object()->$name();
}

sub _object {
    my ($self) = @_;
    return $self->{'object'};
}

sub attributes {
    my ($self) = @_;    
    my @attr = keys %{$self->{'object'}};
    my $rtv = [];
    for(my $i=0;$i<@attr; $i++) {
        push(@$rtv, $attr[$i]) unless ( $attr[$i] =~ /_.*/ );
    }
    return @$rtv;
}

sub delete {
    my ($self) = @_;
    #$self->_object()->delete();
    warn "Deleting object!";
    return;
}

sub DESTROY {}

sub AUTOLOAD {
    my $self = shift;
    my $call = our $AUTOLOAD;
    $call =~ s/.*://;
    return $self->{'object'}->$call(@_);
}

1;
