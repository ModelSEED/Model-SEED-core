########################################################################
# ModelSEED::MS::IndexedObject - This is the moose object corresponding to the IndexedObject object
# Author: Christopher Henry, Scott Devoid, and Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
use strict;


#use ModelSEED::MS::BaseObject;
package ModelSEED::MS::IndexedObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';

has om      => (is => 'rw',isa => 'ModelSEED::CoreApi');
has indices => (is => 'rw',isa => 'HashRef',lazy => 1,builder => '_buildindices');

######################################################################
#Object addition functions
######################################################################
sub add {
    my ($self,$object) = @_;
    $object->parent($self);
    #Checking if an object matching the input object already exists
    my $type = $object->_type();
    my $oldObj = $self->getObject({type => $type,query => {uuid => $object->uuid()}});
    if (!defined($oldObj)) {
    	$oldObj = $self->getObject({type => $type,query => {id => $object->id()}});
    } elsif ($oldObj->id() ne $object->id()) {
    	ModelSEED::utilities::ERROR("Added object has identical uuid to an object in the database, but ids are different!");		
    }
    if (defined($oldObj)) {
    	if ($oldObj->locked() != 1) {
    		$object->uuid($oldObj->uuid());
    	}
    	my $list = $self->$type();
    	for (my $i=0; $i < @{$list}; $i++) {
    		if ($list->[$i] eq $oldObj) {
    			$list->[$i] = $object;
    		}
    	}
    	$self->clearIndex({type=>$type});
    } else {
    	push(@{$self->$type()},$object);
    	if (defined($self->indices()->{$type})) {
    		foreach my $attribute (keys(%{$self->indices()->{$type}})) {
    			push(@{$self->indices()->{$type}->{$attribute}->{$object->$attribute()}},$object);
    		}
    	}
    }
}

######################################################################
#Query Functions
######################################################################
sub getObject {
	my ($self,$type,$query) = @_;
	my $objects = $self->getObjects($type,$query);
	return $objects->[0];
}

sub getObjects {
    my ($self,$type,$query) = @_;
    if(!defined($type) || !defined($query) || ref($query) ne 'HASH') {
        # Calling utilities::ARGS takes ~ 10 microseconds
        # right now we are calling getObjects ~ 200,000 for biochem
        # initialization, so removing this shaves 2 seconds off start time.
    	ModelSEED::utilities::ERROR("Bad arguments to getObjects.");
    }
    # resultSet is a map of $object => $object
    my $resultSet;
    my $indices = $self->indices;
    while ( my ($attribute, $value) = each %$query ) {
        # Build the index if it does not already exist
        unless (defined($indices->{$type}) &&
                defined($indices->{$type}->{$attribute})) {
    		$self->buildIndex({type => $type, attribute => $attribute});
    	}
        my $index = $indices->{$type};
        my $newHits = $index->{$attribute}->{$value};
        # If any index returns empty, return empty.
        return [] if(!defined($newHits) || @$newHits == 0);
        # Build the current resultSet map $object => $object
        my $newResultSet = { map { $_ => $_ } @$newHits };
        if(!defined($resultSet)) {
            # Use the current result set if %resultSet is empty,
            # which will only happen on the first time through the loop.
            $resultSet = $newResultSet; 
            next;
        } else {
            # Otherwise we delete entries in our current $resultSet that
            # are not defined within the $newResultSet. By grepping and
            # deleting we can do this in-place in $resultSet
            delete $resultSet->{ grep { !defined($newResultSet->{$_}) } keys %$resultSet };
        }
    }
    return [values %$resultSet];
}

sub clearIndex {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		type => undef,
		attribute => undef
	});
	if (!defined($args->{type})) {
		$self->indices({});
	} else {
		$self->checkType($args->{type});
		if (!defined($args->{attribute})) {
			$self->indices->{$args->{type}} = {};	
		} else {
			$self->indices->{$args->{type}}->{$args->{attribute}} = {};
		}
	}
}

sub buildIndex {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["type","attribute"],{});
	my $function = $self->checkType($args->{type});
	my $objects = $self->$function();
	my $attribute = $args->{attribute};
	for (my $i=0; $i < @{$objects}; $i++) {
		push(@{$self->indices->{$args->{type}}->{$attribute}->{$objects->[$i]->$attribute()}},$objects->[$i]);
	}
}

sub save {
    my ($self, $om) = @_;
	$om = $self->om unless (defined($om));
    if (!defined($om)) {
        ModelSEED::utilities::ERROR("No ObjectManager");
    }
    my $newuuid = $om->save_object({user => $self->user(),data => $self->serializeToDB()});
    $self->uuid($newuuid);
}

sub _buildindices { return {}; }

__PACKAGE__->meta->make_immutable;
1;
