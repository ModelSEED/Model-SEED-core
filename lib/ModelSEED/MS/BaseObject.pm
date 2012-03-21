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
    for my $attr ( $meta->get_all_attributes ) {
		if ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
    		my $class = 'ModelSEED::MS::'.$1;
    		my $function = $attr->name();
			my $dataArray = $self->$function();
			my $newData;
			foreach my $data (@{$dataArray}) {
				$data->{parent} = $self;
				push(@{$newData},$class->new($data));
			}
			$self->$function($newData);
		} elsif ($attr->type() =~ m/hasharray\((.+)\)/) {
    		my $parameters = [split(/,/,$1)];
    		my $class = 'ModelSEED::MS::'.$parameters->[0];
    		my $attribute = $parameters->[1];
    		my $function = $attr->name();
			my $dataArray = $self->$function();
			my $newData;
			foreach my $data (@{$dataArray}) {
				$data->{parent} = $self;
				push(@{$newData->{$data->{$attribute}}},$class->new($data));
			}
			$self->$function($newData);
		}
	}
}

sub serializeToDB {
	my ($self) = @_;
	my $data = {};
	for my $attr ( $meta->get_all_attributes ) {
		my $name = $attr->name();
		if ($attr->type() eq "attribute") {
			$data->{$name} = $self->$name();
		} elsif ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
			my $class = $1;
			my $arrayRef = $self->$name();
			foreach my $subobject (@{$arrayRef}) {
				push(@{$data->{$attr}},$subobject->serializeToDB());
			}
		} elsif ($attr->type() eq m/hasharray\((.+)\)/) {
			my $hashRef = $self->$attr();
			foreach my $key (keys(%{$hashRef})) {
				foreach my $obj (@{$hashRef->{$key}}) {
					push(@{$data->{$attr}},$obj->serializeToDB());
				}	
			}
		}
	}
}

#if ($attr->type() =~ /solink\((.+),(.+),(.+),(.+)\)/) {
#					my $function = $4;
#					my $linkedObject = $self->getLinkedObject($1,$2,$3,$self->$function());
#					push(@{$newData},$linkedObject);
#				} els

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
