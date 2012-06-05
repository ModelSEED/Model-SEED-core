########################################################################
# ModelSEED::MS::Factories - This is the factory for producing the moose objects from the SEED data
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use ModelSEED::utilities;
#use ModelSEED::Store;
package ModelSEED::MS::Factories::ExchangeFormatFactory;
use Moose;
use namespace::autoclean;
#***********************************************************************************************************
# ATTRIBUTES:
#***********************************************************************************************************
has store => ( is => 'rw', isa => 'ModelSEED::Store', lazy => 1, builder => '_buildstore' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildstore {
	my ($self) = @_;
	return ModelSEED::Store->new();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 parseExchangeFileArray
Definition:
	{} = ModelSEED::MS::Biochemistry->parseExchangeFileArray({
		array => [string](REQ)
	});
Description:
	Parses the exchange file array into a attribute and subobject hash
=cut
sub parseExchangeFileArray {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["array"],{});
	my $array = $args->{array};
	my $section = "none";
	my $data;
	my $headings;
	for (my $i=0; $i < @{$array}; $i++) {
		if ($array->[$i] =~ m/^Attributes/) {
			$section = "attributes";
		} elsif ($array->[$i] eq "}") {
			$section = "none";
		} elsif ($section eq "attributes") {
			$array->[$i] =~ s/^[\s\t]+//g;
			my $arrayTwo = [split(/:/,$array->[$i])];
			$data->{$arrayTwo->[0]} = $arrayTwo->[1];
		} elsif ($array->[$i] =~ m/^([a-zA-Z])\s*\((.+)\)/ && $section eq "none") {
			$section = $1;
			$headings = [split(/\t/,$2)];
		} elsif ($section ne "none") {
			my $arrayTwo = [split(/:/,$array->[$i])];
			my $subobjectData;
			for (my $j=0; $j < @{$headings}; $j++) {
				$subobjectData->{$headings->[$j]} = $arrayTwo->[$j];
			}
			push(@{$data->{$section}},$subobjectData);
		}
	}
	return $data;
}
=head3 buildObjectFromExchangeFileArray
Definition:
	ModelSEED::MS::?? = ModelSEED::MS::Biochemistry->buildObjectFromExchangeFileArray({
		array => [string](REQ)
	});
Description:
	Parses the exchange file array into a attribute and subobject hash
=cut
sub buildObjectFromExchangeFileArray {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["array"],{
		Biochemistry => undef,
		Mapping => undef,
		Model => undef,
		Annotation => undef
	});
	my $data = $self->parseExchangeFileArray($args);
	#The data object must have an ID, which is used to identify the type
	if (!defined($data->{id})) {
		ModelSEED::utilities::ERROR("Input exchange file must have ID!");
	}
	my $refdata = $self->reconcileReference($data->{id});
	delete $data->{id};
	#Checking for shortened names and array-type attributes
	my $dbclass = 'ModelSEED::MS::DB::'.$refdata->{class};
	my $class = 'ModelSEED::MS::'.$refdata->{class};
	for my $attr ( $dbclass->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
			my $name = $attr->name();
			if ($attr->type() eq "attribute") {
				if ($attr->type_constraint() =~ m/ArrayRef/ && defined($data->{$name})) {
					$data->{$name} = [split(/\|/,$data->{$name})];
				}
				if ($name =~ m/(.+)_uuid$/ && !defined($data->{$name})) {
					my $shortname = $1;
					if (defined($data->{$shortname})) {
						$data->{$name} = $data->{$shortname};
						delete $data->{$shortname};
					}
				}
			}
		}
	}
	#Parsing through all attributes looking for and reconciling parent references
	my $parentObjects = {
		Biochemistry => 1,
		Annotation => 1,
		Model => 1,
		Mapping => 1
	};
	my $parents;
	foreach my $att (keys(%{$data})) {
		my $refData = $self->reconcileReference($data->{$att});
		if (defined($refData)) {
			if (defined($parentObjects->{$refData->{class}})) {
				if (defined($args->{$refData->{class}})) {
					$parents->{$refData->{class}} = $args->{$refData->{class}};
				} elsif (defined($args->{store})) {
					$parents->{$refData->{class}} = $self->store()->get_object($data->{$att});	
				}
				if (defined($parents->{$refData->{class}})) {
					$data->{$att} = $parents->{$refData->{class}}->uuid();
				}
			}
		}	
	}
	my $subobjectParents = {
			Reaction => "Biochemistry",
			Media => "Biochemistry",
			Compartment => "Biochemistry"
	};
	my $subobjectAttributes = {
			Reaction => "reactions",
			Media => "media",
			Compartment => "compartments"
	};
	#Parsing through all attributes looking for and reconciling all non-parent references
	foreach my $att (keys(%{$data})) {
		my $refData = $self->reconcileReference($data->{$att});
		if (defined($refData)) {
			if ($refData->{type} eq "uuid") {
				$data->{$att} = $refData->{id};
			} elsif (!defined($parentObjects->{$refData->{class}}) && defined($subobjectParents->{$refData->{class}})) {
				if (defined($parents->{$subobjectParents->{$refData->{class}}})) {
					my $obj;
					if ($refData->{type} eq "name" || $refData->{type} eq "abbreviation") {
						$obj = $parents->{$subobjectParents->{$refData->{class}}}->queryObject($subobjectAttributes->{$refData->{class}},{$refData->{type} => $refData->{id}});
					} else {
						$obj = $parents->{$subobjectParents->{$refData->{class}}}->getObjectByAlias($subobjectAttributes->{$refData->{class}},$refData->{id},$refData->{type});
					}
					if (defined($obj)) {
						$data->{$att} = $obj->uuid();	
					}
				}	
			}
		}	
	}
	return $class->new($data);
}
=head3 reconcileReference
Definition:
	{
		class => string,
		id => string,
		type => string
	} = ModelSEED::MS::Biochemistry->reconcileReference(string);
Description:
	Parses the input reference and translates to class, id, and type
=cut
sub reconcileReference {
	my ($self,$ref) = @_;
	my $output;
	if ($ref =~ m/^([a-zA-z]+)\/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/) {
		$output->{class} = $1;
		$output->{id} = $2;
		$output->{type} = "uuid";
	} elsif ($ref =~ m/^([a-zA-z]+)\/([^\/]+)\/([^\/]+)/) {
		$output->{class} = $1;
		$output->{type} = $2;
		$output->{id} = $3;
	}
	return $output;
}

__PACKAGE__->meta->make_immutable;
