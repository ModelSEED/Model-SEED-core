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
has 'uuid' => (is => 'ro', isa => 'Str', required => 1);
has 'modDate' => (is => 'ro', isa => 'Str', required => 1);
has 'id' => (is => 'ro', isa => 'Str', required => 1);
has 'locked' => (is => 'ro', isa => 'Int', required => 1);
has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'abbreviation' => (is => 'ro', isa => 'Str', required => 1);
has 'cksum' => (is => 'ro', isa => 'Str', required => 1);
has 'unchargedFormula' => (is => 'ro', isa => 'Str', required => 1);
has 'formula' => (is => 'ro', isa => 'Str', required => 1);
has 'mass' => (is => 'ro', isa => 'Str', required => 1);
has 'defaultCharge' => (is => 'ro', isa => 'Str', required => 1);
has 'deltaG' => (is => 'ro', isa => 'Str', required => 1);
has 'deltaGErr' => (is => 'ro', isa => 'Str', required => 1);
#Subobjects
has 'aliases' => (is => 'ro', isa => 'HashRef', required => 1,default => sub{{
	name => [],
	searchname => []
}});
has 'structures' => (is => 'ro', isa => 'HashRef', required => 1,default => sub{{}});
has 'sets' => (is => 'ro', isa => 'HashRef', required => 1,default => sub{{}});
has 'pKs' => (is => 'ro', isa => 'ArrayRef[HashRef]', required => 1,default => sub{{}});
#Object data
has 'loadedSubObjects' => (is => 'ro',isa => 'HashRef[Str]',required => 1);
#Constants
has 'dbAttributes' => (is => 'ro', isa => 'ArrayRef[Str]',default => ["uuid","modDate","locked","id","name","abbreviation","cksum","unchargedFormula","formula","mass","defaultCharge","deltaG","deltaGErr"]);
has 'dbType' => (is => 'ro', isa => 'Str',default => "Compound");

sub BUILDARGS {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,["biochemistry"],{
		rawdata => undef#Raw data of form returned by raw data object manager API
	});
	$params->{loadedSubObjects} = {};
	if (defined($params->{rawdata})) {
		if (defined($params->{rawdata}->{attributes})) {
			foreach my $attribute (keys(%{$params->{rawdata}->{attributes}})) {
				if (defined($params->{rawdata}->{attributes}->{$attribute}) && $params->{rawdata}->{attributes}->{$attribute} ne "undef") {
					$params->{$attribute} = $params->{rawdata}->{attributes}->{$attribute};
				}
			}
		}
		if (defined($params->{rawdata}->{relations}->{compoundsets})) {
			$params->{loadedSubObjects}->{compoundsets} = 1;
			foreach my $set (@{$params->{rawdata}->{relations}->{compoundsets}}) {
				my $cpdset = $params->{biochemistry}->getCompoundSet({attribute => "uuid",value => $set->{attributes}->{uuid}});
				if (!defined($cpdset)) {
					ModelSEED::utilities::ERROR("Could not find compoundset ".$set->{attributes}->{uuid}." in parent biochemistry!");	
				}
				push(@{$params->{sets}->{$set->{attributes}->{type}}},$cpdset);
			}
		}
		if (defined($params->{rawdata}->{relations}->{aliases})) {
			$params->{loadedSubObjects}->{CompoundAlias} = 1;
			foreach my $alias (@{$params->{rawdata}->{relations}->{aliases}}) {
				push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
			}
		}
		if (defined($params->{rawdata}->{relations}->{CompoundStructure})) {
			$params->{loadedSubObjects}->{CompoundStructure} = 1;
			foreach my $structure (@{$params->{rawdata}->{relations}->{CompoundStructure}}) {
				$params->{structures}->{$structure->{attributes}->{type}} = $structure->{attributes}->{structure};
				$params->{structures}->{$structure->{attributes}->{type}."_cksum"} = $structure->{attributes}->{cksum};
			}
		}
		if (defined($params->{rawdata}->{relations}->{CompoundPk})) {
			$params->{loadedSubObjects}->{CompoundPk} = 1;
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
	if (defined($self->{loadedSubObjects}->{CompoundAlias})) {
		foreach my $aliastype (keys(%{$self->aliases()})) {
			foreach my $alias (@{$self->aliases()->{$aliastype}}) {
				push(@{$data->{relations}->{CompoundAlias}},{
					type => "CompoundAlias",
					attributes => {
						compound_uuid => $self->uuid(),
						alias => $alias,
						type => $aliastype
					}
				});
			}
		}
	}
	if (defined($self->{loadedSubObjects}->{CompoundStructure})) {
		foreach my $structureType (keys(%{$self->structures()})) {
			if ($structureType !~ m/cksum$/) {
				push(@{$data->{relations}->{CompoundStructure}},{
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
	}
	if (defined($self->{loadedSubObjects}->{CompoundPk})) {
		foreach my $pk (@{$self->pKs()}) {
			push(@{$data->{relations}->{CompoundPk}},{
				type => "CompoundPk",
				attributes => {
					compound_uuid => $self->uuid(),
        			atom => $pk->{atom},
        			pk => $pk->{pk},
       				type => $pk->{type}
				}
			});
		}
	}
	return $data;
}

__PACKAGE__->meta->make_immutable;
1;