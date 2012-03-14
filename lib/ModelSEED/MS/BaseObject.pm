########################################################################
# ModelSEED::MS::BaseObject - This is a base object that serves as a foundation for all other objects
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
use strict;
use ModelSEED::utilities;
package ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
use DateTime;
use Data::UUID;
use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

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
				my $function = $subObjects->{compound_uuid};
				my $linkedObject = $self->getLinkedObject($subObjects->{parent},$subObjects->{class},$subObjects->{query},$self->$function());
				push(@{$newData},$linkedObject);
			} elsif ($subObject->{type} =~ m/hasharray\(.+\)/) {
				my $parameters = [split(/,/,$1)];
				push(@{$newData->{$data->{$parameters->[0]}}},$data->{$parameters->[1]});
			} else {
				my $class = "ModelSEED::MS::".$subObject->{Class};
				push(@{$newData},$class->new($data);
			}
		}
		$self->$function($newData);
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
