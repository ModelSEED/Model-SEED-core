package ModelSEEDObject::CompositeObject.pm;
#===============================================================================
#
#         FILE:  CompositeObject.pm
#
#  DESCRIPTION:  ModelSEEDObject.pm for Composite Object Types
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  A composite object is simply an array of objects that implement the
#                ModelSEEDObject abstract type. The composite object implements The
#                ModelSEEDObject abstract type over that array, allowing objects to
#                be composed out of multiple different object and databse types.
#       AUTHOR:  Scott Devoid (devoid@ci.uchicago.edu) 
#      COMPANY:  Computation Institute, University of Chicago 
#      VERSION:  1.0
#      CREATED:  08/20/10 13:56:11
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use AutoLoader;

sub new {
    my ($type, $objectArrayRef) = @_;
    my $self = {
        'objects' => $objectArrayRef,
        'type' => $type,
    }
    bless $self;
    return $self;
}


sub attr {
    my ($self, $name, $value) = @_;
    unless(defined($name)) {
        warn "Subroutine attr() called without attribute name!";
        return undef;
    }
    my $componentObject;
    if($name =~ m/(.+)\.(.+)/) {
        $componentObject = $1;
        $name = $2;
        for(my $i=0; $i<@{$self->{'objects'}}; $i++) {
            my $currObject = $self->{'objects'}->[$i];
            if($componentObject eq  $currObject->type()) {
                if(defined($value)) {
                    return $currObject->attr($name, $value);
                } else {
                    return $currObject->attr($name);
                }
            }
        }
    } else {
        warn "Call to attr() must be of format 'ObjectType.AttributeName'";
        return undef;
    }
}

sub attributes {
    my ($self) = @_;
    my $attr = [];
    for(my $i=0; $i<@{$self->{'objects'}}; $i++) {
        my $currObject = $self->{'objects'}->[$i];
        my $objAttr = $currObject->attributes();
        my $type = $currObject->type();
        push(@$attr, map($type.".".$_) @$objAttr);
    }
    return $attr;
}

sub type {
    my ($self) = @_;
    return $self->{'type'};
}
 
sub delete {
    my ($self, ) = @_;
    my $rtv = [];
    for(my $i=0; $i<@{$self->{'objects'}}; $i++) {
        my $currObject = $self->{'objects'}->[$i];
        push(@$rtv, $currObject->delete());
    }
    delete $self;
    return $rtv;
} 
        
sub AUTOLOAD {
    my $self = shift;
    my $call = our $AUTOLOAD;
    if($call =~ m/(.+)\.(.+)/) {
        my $obj = $1;
        $call = $2;
        for(my $i=0; $i<@{$self->{'objects'}}; $i++) {
            my $currObject = $self->{'objects'}->[$i];
            if($currObject->type() eq $obj) {
                return $currObject->$call(@_);
            }
        }
    }
    return "Unknown subroutine!";
}
