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
    		my $class = $1;
    		my $function = $attr->name();
			my $dataArray = $self->$function();
			my $newData;
			foreach my $data (@{$dataArray}) {
				$data->{parent} = $self;
				if ($attr->type() =~ m/hasharray\((.+),(.+)\)/) {
					push(@{$newData->{$data->{$1}}},$data->{$2});
				} else {
					$class = 'ModelSEED::MS::'.$class;
					push(@{$newData},$class->new($data));
				}
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
				push(@{$data->{$name}},$subobject->serializeToDB());
			}
		} elsif ($attr->type() eq m/hasharray\((.+)\)/) {
			my $parameters = [split(/,/,$1)];
			my $hashRef = $self->$name();
			foreach my $key (keys(%{$hashRef})) {
				my $newdata = {
					$parameters->[0] => $key,
					$parameters->[1] => $hashRef->{$key}
				};
				if (defined($self->uuid())) {
					$newdata-> {lc($self->_type())."_uuid"} = $self->uuid()
				}
				push(@{$data->{$name}},$newdata);
				
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

#__PACKAGE__->meta->make_immutable;
1;
