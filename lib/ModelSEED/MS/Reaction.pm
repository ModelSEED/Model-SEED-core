########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Compound;
package ModelSEED::MS::Reaction;
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
has 'deltaG' => (is => 'rw', isa => 'Str', required => 1);
has 'deltaGErr' => (is => 'rw', isa => 'Str', required => 1);
has 'compartment_uuid' => (is => 'rw', isa => 'Str', required => 1);
has 'defaultTransproton' => (is => 'rw', isa => 'Num', required => 1,default => 0);
has 'defaultProtons' => (is => 'rw', isa => 'Num', required => 1,default => 0);
has 'reversibility' => (is => 'rw', isa => 'Str', required => 1);
has 'thermoReversibility' => (is => 'rw', isa => 'Str', required => 1);
#Subobjects
has 'aliases' => (is => 'rw', isa => 'HashRef', required => 1);
has 'sets' => (is => 'rw', isa => 'HashRef',default => sub{{}});
has 'reactants' => (is => 'rw', isa => 'ArrayRef[HashArray]', required => 1);
has 'transported' => (is => 'rw', isa => 'ArrayRef[HashArray]', required => 1);
#Constants
has 'dbAttributes' => (is => 'ro', isa => 'ArrayRef[Str]',default => ["uuid","modDate","locked","id","name","abbreviation","cksum","equation","deltaG","deltaGErr","reversibility","thermoReversibility","defaultProtons","compartment_uuid","defaultTransproton"]);
has 'dbType' => (is => 'ro', isa => 'Str',default => "Reaction");

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
		if (defined($params->{rawdata}->{relations}->{reagents})) {
			$params->{reactants} = [];
			$params->{transported} = [];
			my $cpd = $params->{biochemistry}->getCompound({uuid => $reagent->{attributes}->{compound_uuid}});
			if (!defined($cpd)) {
				ModelSEED::utilities::ERROR("Could not find reaction compound ".$reagent->{attributes}->{compound_uuid}." in parent biochemistry!");	
			}
			my ($reactants,$products,$imported,$exported);
			foreach my $reagent (@{$params->{rawdata}->{relations}->{reagents}}) {
				if ($reagent->{attributes}->{compartmentIndex} == 0) {
					if ($reagent->{attributes}->{coefficient} < 0) {
						push(@{$reactants},{
							coefficient => $reagent->{attributes}->{coefficient},
							compound => $cpd,
							cofactor => $reagent->{attributes}->{cofactor}
						});
					} elsif ($reagent->{attributes}->{coefficient} > 0) {
						push(@{$products},{
							coefficient => $reagent->{attributes}->{coefficient},
							compound => $cpd,
							cofactor => $reagent->{attributes}->{cofactor}
						});
					}
				} else {
					if ($reagent->{attributes}->{coefficient} < 0) {
						push(@{$exported},{
							compartment => $reagent->{attributes}->{compartmentIndex},
							coefficient => $reagent->{attributes}->{coefficient},
							compound => $cpd,
							cofactor => $reagent->{attributes}->{cofactor}
						});
					} elsif ($reagent->{attributes}->{coefficient} > 0) {
						push(@{$imported},{
							compartment => $reagent->{attributes}->{compartmentIndex},
							coefficient => $reagent->{attributes}->{coefficient},
							compound => $cpd,
							cofactor => $reagent->{attributes}->{cofactor}
						});
					}
				}
			}
			push(@{$params->{reactants}},@{$reactants});
			push(@{$params->{reactants}},@{$products});
			push(@{$params->{transported}},@{$imported});
			push(@{$params->{transported}},@{$exported});
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
	$data->{relations}->{reaction_aliases} = [];
	foreach my $aliastype (keys(%{$self->aliases()})) {
		foreach my $alias (@{$self->aliases()->{$aliastype}}) {
			push(@{$data->{relations}->{reaction_aliases}},{
				type => "ReactionAlias",
				attributes => {
					reaction_uuid => $self->uuid(),
					alias => $alias,
					type => $aliastype
				}
			});
		}
	}
	$data->{relations}->{reagents} = [];
	foreach my $reactant (@{$self->reactants()}) {
		push(@{$data->{relations}->{reagents}},{
			type => "Reagent",
			attributes => {
				reaction_uuid => $self->uuid(),
				compound_uuid => $reactant->{compound}->uuid(),
				compartmentIndex => 0,
				coefficient => $reactant->{coefficient},
				cofactor => $reactant->{cofactor}
			}					
		});
	}
	foreach my $reactant (@{$self->transported()}) {
		push(@{$data->{relations}->{reagents}},{
			type => "Reagent",
			attributes => {
				reaction_uuid => $self->uuid(),
				compound_uuid => $reactant->{compound}->uuid(),
				compartmentIndex => $reactant->{compartment},
				coefficient => $reactant->{coefficient},
				cofactor => $reactant->{cofactor}
			}					
		});
	}
	return $data;
}

__PACKAGE__->meta->make_immutable;
1;