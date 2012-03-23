########################################################################
# ModelSEED::MS::BaseObject - This is a base object that serves as a foundation for all other objects
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
use strict;
use ModelSEED::utilities;
use namespace::autoclean;
use ModelSEED::MS::Metadata::Types;
use DateTime;
use Data::UUID;
use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

package ModelSEED::Meta::Attribute::Typed;
use Moose;
extends 'Moose::Meta::Attribute';

has type => (
      is        => 'rw',
      isa       => 'Str',
      predicate => 'has_type',
);

package Moose::Meta::Attribute::Custom::Typed;
sub register_implementation { 'ModelSEED::Meta::Attribute::Typed' }

package ModelSEED::MS::BaseObject;
use Moose;

my $meta = __PACKAGE__->meta;

sub BUILD {
    my ($self,$params) = @_;
    my $class = 'ModelSEED::MS::DB::'.$self->_type();
    for my $attr ( $class->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
			if ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
	    		my $subclass = 'ModelSEED::MS::'.$1;
	    		my $function = $attr->name();
				my $dataArray = $self->$function();
				my $newData = [];
				foreach my $data (@{$dataArray}) {
					$data->{parent} = $self;
					push(@{$newData},$subclass->new($data));
				}
				$self->$function($newData);
			} elsif ($attr->type() =~ m/hasharray\((.+)\)/) {
	    		my $parameters = [split(/,/,$1)];
	    		my $subclass = 'ModelSEED::MS::'.$parameters->[0];
	    		my $attribute = $parameters->[1];
	    		my $function = $attr->name();
				my $dataArray = $self->$function();
				my $newData = {};
				foreach my $data (@{$dataArray}) {
					$data->{parent} = $self;
					push(@{$newData->{$data->{$attribute}}},$subclass->new($data));
				}
				$self->$function($newData);
			}
		}
    }
}

sub serializeToDB {
	my ($self) = @_;
	my $data = {};
	my $class = 'ModelSEED::MS::DB::'.$self->_type();
	for my $attr ( $class->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
			my $name = $attr->name();
			if ($attr->type() eq "attribute") {
				$data->{$name} = $self->$name();
			} elsif ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
				my $arrayRef = $self->$name();
				foreach my $subobject (@{$arrayRef}) {
					push(@{$data->{$name}},$subobject->serializeToDB());
				}
			} elsif ($attr->type() =~ m/hasharray\((.+)\)/) {
				my $hashRef = $self->$attr();
				foreach my $key (keys(%{$hashRef})) {
					foreach my $obj (@{$hashRef->{$key}}) {
						push(@{$data->{$name}},$obj->serializeToDB());
					}	
				}
			}
		}
	}
	return $data;
}

######################################################################
#Object addition functions
######################################################################
sub create {
	my ($self,$type,$data) = @_;
	if (!defined($self->_typeToFunction()) || !defined($self->_typeToFunction()->{$type})) {
    	ModelSEED::utilities::ERROR("Object doesn't have a subobject of type ".$type);	
    }
	my $package = "ModelSEED::MS::$type";
	eval {
		require $package;
	};
	my $object = $package->new($data);
	$self->add($object);
	return $object;
}

sub add {
    my ($self,$object) = @_;
    my $type = $object->_type();
    if (!defined($self->_typeToFunction()) || !defined($self->_typeToFunction()->{$type})) {
    	ModelSEED::utilities::ERROR("Object doesn't have a subobject of type ".$type);	
    }
    my $function = $self->_typeToFunction()->{$type};
    $object->parent($self);
	push(@{$self->$function()},$object);
}

sub getLinkedObject {
	my ($self,$soureType,$type,$attribute,$value) = @_;
	$soureType = lc($soureType);
	my $parent = $self->$soureType();
	my $object;
	if (ref($parent) eq "ModelSEED::MS::ObjectManager") {
		$object = $parent->get($value);
	} else {
		$object = $parent->getObject($type,{$attribute => $value});
	}
	if (!defined($object)) {
		ModelSEED::utilities::ERROR($type.' '.$value." not found in ".$soureType."!");
	}
	return $object;
}

sub biochemistry {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->biochemistry();
	} elsif (ref($parent) eq "ModelSEED::MS::Biochemistry") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find Biochemistry object in tree!");
}

sub model {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->model();
	} elsif (ref($parent) eq "ModelSEED::MS::Model") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find Model object in tree!");
}

sub annotation {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->annotation();
	} elsif (ref($parent) eq "ModelSEED::MS::Annotation") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find Annotation object in tree!");
}

sub mapping {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->mapping();
	} elsif (ref($parent) eq "ModelSEED::MS::Mapping") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find mapping object in tree!");
}

sub objectmanager {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->objectmanager();
	}
	return $parent;
}

#__PACKAGE__->meta->make_immutable;
1;
