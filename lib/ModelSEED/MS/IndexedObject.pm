########################################################################
# ModelSEED::MS::IndexedObject - This is the moose object corresponding to the IndexedObject object
# Author: Christopher Henry, Scott Devoid, and Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
package ModelSEED::MS::IndexedObject;

use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;

use Data::Dumper;

extends 'ModelSEED::MS::BaseObject';

has indices => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );
######################################################################
#Object addition functions
######################################################################
sub add {
    my ($self, $attribute, $data_or_object) = @_;
    my $attr_info = $self->_subobjects($attribute);
    if (!defined($attr_info)) {
        ModelSEED::utilities::ERROR("Object doesn't have subobject with name: $attribute");
    }
    my $obj_info = {
        created => 0,
        class => $attr_info->{class}
    };
    my $ref = ref($data_or_object);
    if ($ref eq "HASH") {
        # need to create object first
        foreach my $att (keys(%$data_or_object)) {
        	if (!defined($data_or_object->{$att})) {
        		delete $data_or_object->{$att};
        	}
        }
        $obj_info->{data} = $data_or_object;
        $self->_build_object($attribute, $obj_info);
    } elsif ($ref =~ m/ModelSEED::MS/) {
        $obj_info->{object} = $data_or_object;
        $obj_info->{created} = 1;
    } else {
        ModelSEED::utilities::ERROR("Neither data nor object passed into " . ref($self) . "->add");
    }
    my $method = "_$attribute";
	$obj_info->{object}->parent($self);
	#Checking if another object with the same uuid is already present
	if (defined($obj_info->{object}->_attributes("uuid"))) {
		my $obj = $self->getObject($attribute,$obj_info->{object}->uuid());
		if (defined($obj) && $obj ne $obj_info->{object}) {
			for (my $i=0; $i < @{$self->$method()}; $i++) {
				if ($self->$method()->[$i] eq $obj) {
					$self->$method()->[$i] = $obj_info->{object};
				}
			}
			$self->clearIndex({attribute=>$attribute});
			return $obj_info->{object};
		}
	}
	#Updating the indecies
	if (defined($self->indices->{$attribute})) {
		my $indices = $self->indices->{$attribute};
		foreach my $attribute (keys(%{$indices})) {
			push(@{$indices->{$attribute}->{$obj_info->{object}->$attribute()}},$obj_info);
		}
	}
	push(@{$self->$method},$obj_info); 
    return $obj_info->{object};
};

######################################################################
#Alias Functions
######################################################################
sub addAlias {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["attribute","aliasName","alias","uuid"],{
		source => undef
	});
	if (!defined($args->{source})) {
		$args->{source} = $args->{aliasName};
	}
	#Checking for alias set
	my $aliasSet = $self->queryObject("aliasSets",{
		name => $args->{aliasName},
		attribute => $args->{attribute}
	});
	if (!defined($aliasSet)) {
		my $attInfo = $self->_subobjects($args->{attribute});
		#Creating alias set
		$aliasSet = $self->add("aliasSets",{
			name => $args->{aliasName},
			source => $args->{source},
			attribute => $args->{attribute},
			class => $attInfo->{class}
		});
	}
	if (defined($aliasSet->aliases()->{$args->{alias}})) {
		my $aliases = $aliasSet->aliases()->{$args->{alias}};
		for (my $i=0; $i < @{$aliases}; $i++) {
			if ($aliases->[$i] eq $args->{uuid}) {
				return;	
			}
		}
	}
	push(@{$aliasSet->aliases()->{$args->{alias}}},$args->{uuid});
}

sub getObjectByAlias {
	my ($self,$attribute,$alias,$aliasName) = @_;
	my $objs = $self->getObjectsByAlias($attribute,$alias,$aliasName);
	if (defined($objs->[0])) {
        return $objs->[0];
    } else {
        return undef;
    }
}

sub getObjectsByAlias {
	my ($self,$attribute,$alias,$aliasName) = @_;
	my $aliasSet = $self->queryObject("aliasSets",{
		name => $aliasName,
		attribute => $attribute
	});
	if (!defined($aliasSet)) {
		ModelSEED::utilities::USEWARNING("Alias set '".$aliasName."' not found in database!");
		return [];
	}
	if (defined($aliasSet->aliases()->{$alias})) {
		my $array = $aliasSet->aliases()->{$alias};
		return $self->getObjects($attribute,$aliasSet->aliases()->{$alias});
	}
	return [];
}

######################################################################
#Object retreival functions
######################################################################
sub getObject {
    my ($self, $attribute, $uuid) = @_;
    my $objs = $self->getObjects($attribute, [$uuid]);
    if (scalar @$objs == 1) {
        return $objs->[0];
    } else {
        return undef;
    }
}

sub getObjects {
    my ($self, $attribute, $uuids) = @_;
	#Checking arguments
	if(!defined($attribute) || !defined($uuids) || ref($uuids) ne 'ARRAY') {
    	ModelSEED::utilities::ERROR("Bad arguments to getObjects.");
    }
    #Retreiving objects
    my $results = [];
    if (!defined($self->indices->{$attribute}->{uuid})) {
    	$self->_buildIndex({attribute=>$attribute,subAttribute=>"uuid"});
    }
    my $index = $self->indices->{$attribute}->{uuid};
    foreach my $obj_uuid (@$uuids) {
        my $obj_info = $index->{$obj_uuid}->[0];
        if (defined($obj_info)) {
            push(@$results, $self->_build_object($attribute, $obj_info));
        } else {
            push(@$results, undef);
        }
    }
    return $results;
}

sub queryObject {
    my ($self,$attribute,$query) = @_;
    my $objs = $self->queryObjects($attribute,$query);
    if (defined($objs->[0])) {
        return $objs->[0];
    } else {
        return undef;
    }
}

sub queryObjects {
    my ($self,$attribute,$query) = @_;
	#Checking arguments
	if(!defined($attribute) || !defined($query) || ref($query) ne 'HASH') {
		ModelSEED::utilities::ERROR("Bad arguments to queryObjects.");
    }
    #ResultSet is a map of $object => $object
    my $resultSet;
    my $indices = $self->indices;
    while ( my ($subAttribute, $value) = each %$query ) {
        #Build the index if it does not already exist
        unless (defined($indices->{$attribute}) &&
                defined($indices->{$attribute}->{$subAttribute})) {
    		$self->_buildIndex({attribute => $attribute, subAttribute => $subAttribute});
    	}
        my $newHits = $indices->{$attribute}->{$subAttribute}->{$value};
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
    my $results = [];
    foreach my $value (keys(%$resultSet)) {
    	push(@$results, $self->_build_object($attribute,$resultSet->{$value}));
    }
    return $results;
}

sub _buildIndex {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["attribute","subAttribute"],{});
	my $att = $args->{attribute};
	my $subatt = $args->{subAttribute};
	my $newIndex  = {};
	my $method = "_$att";
	my $subobjs = $self->$method();
	if (@{$subobjs} > 0) {
		#First we check if all objects need to be built before the index can be constructed
		my $obj = $self->_build_object($att,$subobjs->[0]);
		my $alwaysBuild = 1;
		if (defined($obj->_attributes($subatt))) {
			#The attribute is a base attribute, so we can build the index without building objects
			$alwaysBuild = 0;
		}
		foreach my $so_info (@{$subobjs}) {
			if ($alwaysBuild == 1) {
				$self->_build_object($att,$so_info);
			}
			if ($so_info->{created} == 1) {
				push(@{$newIndex->{$so_info->{object}->$subatt()}},$so_info);
			} else {
				push(@{$newIndex->{$so_info->{data}->{$subatt}}},$so_info);
			}
		}
	}
	$self->indices->{$att}->{$subatt} = $newIndex;
}

sub _clearIndex {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		attribute => undef,
		subAttribute => undef,
	});
	my $att = $args->{attribute};
	my $subatt = $args->{subAttribute};
	if (!defined($att)) {
		$self->indices({});
	} else {
		if (!defined($subatt)) {
			$self->indices->{$att} = {};	
		} else {
			$self->indices->{$att}->{$subatt} = {};
		}
	}
}

1;
