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
    my $objectData = ModelSEED::MS::DB::Definitions::objectDefinitions()->{$self->_type()};
    foreach my $subObject (@{$objectData->{subobjects}}) {
		my $function = $subObject->{name};
		my $dataArray = $self->$function();
		my $newData;
		foreach my $data (@{$dataArray}) {
			$data->{parent} = $self;
			if ($subObject->{type} eq "link") {
				my $function = $subObject->{compound_uuid};
				my $linkedObject = $self->getLinkedObject($subObject->{parent},$subObject->{class},$subObject->{query},$self->$function());
				push(@{$newData},$linkedObject);
			} elsif ($subObject->{type} =~ m/hasharray\((.+)\)/) {
				my $parameters = [split(/,/,$1)];
				push(@{$newData->{$data->{$parameters->[0]}}},$data->{$parameters->[1]});
			} else {
				my $class = "ModelSEED::MS::".$subObject->{Class};
				push(@{$newData},$class->new($data));
			}
		}
		$self->$function($newData);
    }
}

sub serializeToDB {
	my ($self) = @_;
	my $data = {};
	for my $attr ( $meta->get_all_attributes ) {
		if ($attr->type() eq "attribute") {
			my $name = $attr->name();
			$data->{$name} = $self->$name();
		} elsif ($attr->type() eq "child" || $attr->type() eq "encompassed") {
			my $arrayRef = $self->$attr();
			foreach my $subobject (@{$arrayRef}) {
				push(@{$data->{$attr}},$subobject->serializeToDB());
			}
		} elsif ($attr->type() eq m/hasharray\((.+)\)/) {
			my $parameters = [split(/,/,$1)];
			my $hashRef = $self->$attr();
			foreach my $key (keys(%{$hashRef})) {
				my $newdata = {
					$parameters->[0] => $key,
					$parameters->[1] => $hashRef->{$key}
				};
				if (defined($self->uuid())) {
					$newdata-> {lc($self->_type())."_uuid"} = $self->uuid()
				}
				push(@{$data->{$attr}},$newdata);
				
			}
		}
	}
}

sub getLinkedObject {
	my ($self,$soureType,$type,$attribute,$value) = @_;
	$soureType = lc($soureType);
	my $parent = $self->$soureType();
	my $object = $parent->getObject($type,{$attribute => $value});
	if (!defined($object)) {
		ModelSEED::utilities::ERROR($type.' '.$value." not found in ".$soureType."!");
	}
	return $object;
}

sub biochemistry {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::Biochemistry") {
		return $parent->biochemistry();
	}
	return $parent;
}

sub model {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::Model") {
		return $parent->model();
	}
	return $parent;
}

sub annotation {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::Annotation") {
		return $parent->annotation();
	}
	return $parent;
}

sub mapping {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::Mapping") {
		return $parent->mapping();
	}
	return $parent;
}

sub objectmanager {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->objectmanager();
	}
	return $parent;
}

__PACKAGE__->meta->make_immutable;
1;
