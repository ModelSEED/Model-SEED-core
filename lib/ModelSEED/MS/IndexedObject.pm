########################################################################
# ModelSEED::MS::IndexedObject - This is the moose object corresponding to the IndexedObject object
# Author: Christopher Henry, Scott Devoid, and Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::IndexedObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';

has om      => (is => 'rw',isa => 'ModelSEED::CoreApi');
has indices => (is => 'rw',isa => 'HashRef',lazy => 1,builder => '_buildindices');

######################################################################
#Object addition functions
######################################################################

override add => sub {
    my ($self,$attribute, $object) = @_;
    #Checking if an object matching the input object already exists
    if (!defined($object)) {
    	ModelSEED::utilities::ERROR("Can't call add without defined object!");	
    }
    my $type = $object->_type();
    my $function = $self->_typeToFunction()->{$type};
    my $class = 'ModelSEED::MS::DB::'.$object->_type;
    if (defined($class->meta->find_attribute_by_name("uuid"))) {
	    my $oldObj = $self->getObject($type,{uuid => $object->uuid()});
	    if (defined($oldObj)) {
	    	if ($oldObj->locked() != 1) {
	    		$object->uuid($oldObj->uuid());
	    	}
	    	my $list = $self->$function();
	    	for (my $i=0; $i < @{$list}; $i++) {
	    		if ($list->[$i] eq $oldObj) {
	    			$list->[$i] = $object;
	    		}
	    	}
	    	$self->clearIndex({type=>$type});
	    	return;
	    }
    }
	if (defined($self->indices->{$type})) {
		foreach my $att (keys(%{$self->indices->{$type}})) {
			push(@{$self->indices->{$type}->{$att}->{$object->$att()}},$object);
		}
	}
	super();
};

######################################################################
#Alias Functions
######################################################################
sub addAlias {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["objectType","aliasType","alias","uuid"],{
		source => undef
	});
	if (!defined($args->{source})) {
		$args->{source} = $args->{aliasType};
	}
	my $aliasSetType = $args->{objectType}."AliasSet";
	#Checking for alias set
	my $aliasSet = $self->getObject($aliasSetType,{type => $args->{aliasType}});
	if (!defined($aliasSet)) {
		#Creating alias set
		$aliasSet = $self->create($aliasSetType,{
			type => $args->{aliasType},
			source => $args->{source}
		});
	}
	my $objects = $aliasSet->getObjects($args->{objectType}."Alias",{lc($args->{objectType})."_uuid" => $args->{uuid}});
	for (my $i=0; $i < @{$objects}; $i++) {
		if ($objects->[$i]->alias() eq $args->{alias}) {
			return;
		}
	}
	$aliasSet->create($args->{objectType}."Alias",{
		lc($args->{objectType})."_uuid" => $args->{uuid},
		alias => $args->{alias}
	});
	return;
}

sub getObjectsByAlias {
	my ($self,$objectType,$alias,$aliasType) = @_;
	my $aliasSet = $self->getObject($objectType."AliasSet",{type => $aliasType});
	if (!defined($aliasSet)) {
		ModelSEED::utilities::USEWARNING("Alias set '".$aliasType."' not found in database!");
		return undef;
	}
	my $objs = $aliasSet->getObjects($objectType."Alias",{alias => $alias});
	my $result;
	my $function = lc($objectType);
	for (my $i=0; $i < @{$objs}; $i++) {
		push(@{$result},$objs->[$i]->$function());	
	}
	return $result;
}

sub getObjectByAlias {
	my ($self,$objectType,$alias,$aliasType) = @_;
	my $objects = $self->getObjectsByAlias($objectType,$alias,$aliasType);
	if (defined($objects->[0])) {
		return $objects->[0];
	}
	return undef;
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
			#Replacing the "grep" based code, which does not appear to work properly
            foreach my $result (keys(%$resultSet)) {
            	if (!defined($newResultSet->{$result})) {
            		delete $resultSet->{$result};
            	}
            }
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
	my $function = $self->_typeToFunction()->{$args->{type}};
	if (!defined($function)) {
		ModelSEED::utilities::ERROR("Could not find type ".$args->{type}." in object ".$self->_type."!");
	}
	my $objects = $self->$function();
	my $attribute = $args->{attribute};
	$self->indices->{$args->{type}}->{$attribute} = {};
	for (my $i=0; $i < @{$objects}; $i++) {
		push(@{$self->indices->{$args->{type}}->{$attribute}->{$objects->[$i]->$attribute()}},$objects->[$i]);
	}
}

sub save {
    my ($self, $alias, $om) = @_;
    $om = $self->parent() unless (defined($om));
    if (!defined($om)) {
        ModelSEED::utilities::ERROR("No Storage Object");
    }
    my $refstring = lc(substr($self->_type,0,1)).substr($self->_type,1) . "/" . $alias;
    $om->save_object($refstring, $self);
}

sub _buildindices { return {}; }

__PACKAGE__->meta->make_immutable;
1;
