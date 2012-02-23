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
has 'uuid' => (is => 'ro', isa => 'Str', required => 1);
has 'modDate' => (is => 'ro', isa => 'Str', required => 1);
has 'id' => (is => 'ro', isa => 'Str', required => 1);
has 'locked' => (is => 'ro', isa => 'Int', required => 1);
has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'abbreviation' => (is => 'ro', isa => 'Str', required => 1);
has 'cksum' => (is => 'ro', isa => 'Str', required => 1);
has 'deltaG' => (is => 'ro', isa => 'Str', required => 1);
has 'deltaGErr' => (is => 'ro', isa => 'Str', required => 1);
has 'compartment_uuid' => (is => 'ro', isa => 'Str', required => 1);
has 'defaultTransproton' => (is => 'ro', isa => 'Num', required => 1,default => 0);
has 'defaultProtons' => (is => 'ro', isa => 'Num', required => 1,default => 0);
has 'reversibility' => (is => 'ro', isa => 'Str', required => 1);
has 'thermoReversibility' => (is => 'ro', isa => 'Str', required => 1);
#Subobjects
has 'aliases' => (is => 'ro', isa => 'HashRef', required => 1,default => sub{{
	name => [],
	searchname => []
}});
has 'sets' => (is => 'ro', isa => 'HashRef', required => 1,default => sub{{}});
has 'reactants' => (is => 'ro', isa => 'ArrayRef[HashArray]', required => 1,default => sub{{}});
has 'transported' => (is => 'ro', isa => 'ArrayRef[HashArray]', required => 1,default => sub{{}});
#Object data
has 'loadedSubObjects' => (is => 'ro',isa => 'HashRef[Str]',required => 1);
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
		if (defined($params->{rawdata}->{relations}->{reactionsets})) {
			$params->{loadedSubObjects}->{ReactionsetReaction} = 1;
			foreach my $set (@{$params->{rawdata}->{relations}->{reactionsets}}) {
				my $rxnset = $params->{biochemistry}->getReactionSet({attribute => "uuid",value => $set->{attributes}->{uuid}});
				if (!defined($rxnset)) {
					ModelSEED::utilities::ERROR("Could not find reactionset ".$set->{attributes}->{uuid}." in parent biochemistry!");	
				}
				push(@{$params->{sets}->{$set->{attributes}->{type}}},$rxnset);
			}
		}
		if (defined($params->{rawdata}->{relations}->{aliases})) {
			$params->{loadedSubObjects}->{ReactionAlias} = 1;
			foreach my $alias (@{$params->{rawdata}->{relations}->{aliases}}) {
				push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
			}
		}
		if (defined($params->{rawdata}->{relations}->{reagents})) {
			$params->{loadedSubObjects}->{Reagent} = 1;
			my $cpd = $params->{biochemistry}->getCompound({attribute => "uuid",value => $reagent->{attributes}->{compound_uuid}});
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
	if (defined($self->{loadedSubObjects}->{ReactionAlias})) {
		foreach my $aliastype (keys(%{$self->aliases()})) {
			foreach my $alias (@{$self->aliases()->{$aliastype}}) {
				push(@{$data->{relations}->{ReactionAlias}},{
					type => "ReactionAlias",
					attributes => {
						reaction_uuid => $self->uuid(),
						alias => $alias,
						type => $aliastype
					}
				});
			}
		}
	}
	if (defined($self->{loadedSubObjects}->{Reagent})) {
		foreach my $reactant (@{$self->reactants()}) {
			push(@{$data->{relations}->{Reagent}},{
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
			push(@{$data->{relations}->{Reagent}},{
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
	}
	return $data;
}

__PACKAGE__->meta->make_immutable;
1;