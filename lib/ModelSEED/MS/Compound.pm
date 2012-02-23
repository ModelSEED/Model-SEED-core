########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
package ModelSEED::MS::Compound;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

#Attributes
has 'uuid' => (is => 'rw', isa => 'Str', required => 1);
has 'modDate' => (is => 'rw', isa => 'Str', required => 1);
has 'id' => (is => 'rw', isa => 'Str', required => 1);
has 'locked' => (is => 'rw', isa => 'Int', required => 1);
has 'name' => (is => 'rw', isa => 'Str', required => 1);
has 'abbreviation' => (is => 'rw', isa => 'Str', required => 1);
has 'cksum' => (is => 'rw', isa => 'Str', required => 1);
has 'unchargedFormula' => (is => 'rw', isa => 'Str', required => 1);
has 'formula' => (is => 'rw', isa => 'Str', required => 1);
has 'mass' => (is => 'rw', isa => 'Str', required => 1);
has 'defaultCharge' => (is => 'rw', isa => 'Str', required => 1);
has 'deltaG' => (is => 'rw', isa => 'Str', required => 1);
has 'deltaGErr' => (is => 'rw', isa => 'Str', required => 1);
#Subobjects
has 'aliases' => (is => 'rw', isa => 'HashRef', required => 1);
has 'structures' => (is => 'rw', isa => 'HashRef', required => 1);
has 'sets' => (is => 'rw', isa => 'HashRef', required => 1,default => sub{{}});
has 'pKs' => (is => 'rw', isa => 'ArrayRef[HashRef]', required => 1);
#Constants
has 'dbAttributes' => (is => 'ro', isa => 'ArrayRef[Str]',default => ["uuid","modDate","locked","id","name","abbreviation","cksum","unchargedFormula","formula","mass","defaultCharge","deltaG","deltaGErr"]);
has 'dbType' => (is => 'ro', isa => 'Str',default => "Compound");

sub BUILDARGS {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,["biochemistry"],{
		rawdata => undef#Raw data of form returned by raw data object manager API
	});
	if (defined($params->{rawdata})) {
		if (defined($params->{rawdata}->{attributes})) {
			foreach my $attribute (keys(%{$params->{rawdata}->{attributes}})) {
				if (defined($params->{rawdata}->{attributes}->{$attribute}) && $params->{rawdata}->{attributes}->{$attribute} ne "undef") {
					$params->{$attribute} = $params->{rawdata}->{attributes}->{$attribute};
				}
			}
		}
		if (defined($params->{rawdata}->{relations}->{aliases})) {
			$params->{aliases} = {};
			foreach my $alias (@{$params->{rawdata}->{relations}->{aliases}}) {
				push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
			}
		}
		if (defined($params->{rawdata}->{relations}->{CompoundStructure})) {
			$params->{structures} = {};
			foreach my $structure (@{$params->{rawdata}->{relations}->{CompoundStructure}}) {
				$params->{structures}->{$structure->{attributes}->{type}} = $structure->{attributes}->{structure};
				$params->{structures}->{$structure->{attributes}->{type}."_cksum"} = $structure->{attributes}->{cksum};
			}
		}
		if (defined($params->{rawdata}->{relations}->{CompoundPk})) {
			$params->{pKs} = [];
			foreach my $pk (@{$params->{rawdata}->{relations}->{CompoundPk}}) {
				push(@{$params->{pKs}},{
					atom => $pk->{attributes}->{atom},
					pk => $pk->{attributes}->{pk},
					type => $pk->{attributes}->{type}
				});
			}
		}
	}
	return $params;
}

sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{});
}

sub serializeToDB {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{});
	my $data = {};
	my $attributes = $self->dbAttributes();
	for (my $i=0; $i < @{$attributes}; $i++) {
		my $function = $attributes->[$i];
		$data->{attributes}->{$function} = $self->$function();
	}
	$data->{relations}->{compound_aliases} = [];
	foreach my $aliastype (keys(%{$self->aliases()})) {
		foreach my $alias (@{$self->aliases()->{$aliastype}}) {
			push(@{$data->{relations}->{compound_aliases}},{
				type => "CompoundAlias",
				attributes => {
					compound_uuid => $self->uuid(),
					alias => $alias,
					type => $aliastype
				}
			});
		}
	}
	$data->{relations}->{compound_structures} = [];
	foreach my $structureType (keys(%{$self->structures()})) {
		if ($structureType !~ m/cksum$/) {
			push(@{$data->{relations}->{compound_structures}},{
				type => "CompoundStructure",
				attributes => {
					compound_uuid => $self->uuid(),
					cksum => $self->structures()->{$structureType."_cksum"},
					structure => $self->structures()->{$structureType},
					type => $structureType
				}
			});	
		}
	}
	$data->{relations}->{compound_pk} = [];
	foreach my $pk (@{$self->pKs()}) {
		push(@{$data->{relations}->{compound_pk}},{
			type => "CompoundPk",
			attributes => {
				compound_uuid => $self->uuid(),
       			atom => $pk->{atom},
       			pk => $pk->{pk},
    			type => $pk->{type}
			}
		});
	}
	return $data;
}

__PACKAGE__->meta->make_immutable;
1;