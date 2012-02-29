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
has 'uuid' => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has 'modDate' =>
    (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has 'id'     => (is => 'rw', isa => 'Str', required => 1);
has 'locked' => (is => 'rw', isa => 'Int', default  => 0);
has 'name'   => (is => 'rw', isa => 'Str', default  => "");
has 'abbreviation' => (is => 'rw', isa => 'Str');
has 'cksum' =>
    (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildCksum');
has 'deltaG'              => (is => 'rw', isa => 'Str');
has 'deltaGErr'           => (is => 'rw', isa => 'Str');
has 'compartment_uuid'    => (is => 'rw', isa => 'Str', required => 1);
has 'defaultTransproton'  => (is => 'rw', isa => 'Num', default => 0);
has 'defaultProtons'      => (is => 'rw', isa => 'Num', default => 0);
has 'reversibility'       => (is => 'rw', isa => 'Str', default => '=');
has 'thermoReversibility' => (is => 'rw', isa => 'Str');
has 'equation' =>
    (is => 'ro', isa => 'Str', lazy => 1, builder => '_buildEquation');

#Subobjects
has 'aliases' => (is => 'rw', isa => 'HashRef', default => sub { return {}; });
has 'reactants' => (is => 'rw', isa => 'ArrayRef', default => sub { return []; });
has 'transported' => (is => 'rw', isa => 'ArrayRef', default => sub { return []; });
#Constants
has 'dbAttributes' => ( is => 'ro', isa => 'ArrayRef[Str]', 
    builder => '_buildDbAttributes' );
has 'dbType' => (is => 'ro', isa => 'Str',default => "Reaction");
#Internally maintained variables
has 'changed' => (is => 'rw', isa => 'Bool',default => 0);

sub BUILDARGS {
    my ($self,$params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    my $bio  = $params->{biochemistry};
    delete $params->{biochemistry};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    if(defined($rels)) {
        foreach my $alias (@{$rels->{aliases} || []}) {
            push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
        }
        $params->{reactants} = [];
		$params->{transported} = [];
		my ($reactants,$products,$imported,$exported) = ( [], [], [], [] );
		foreach my $reagent (@{$rels->{reagents}}) {
			my $cpd = $bio->getCompound({uuid => $reagent->{attributes}->{compound_uuid}});
			if (!defined($cpd)) {
				ModelSEED::utilities::ERROR("Could not find reaction compound ".$reagent->{attributes}->{compound_uuid}." in parent biochemistry!");	
			}
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
    delete $params->{relationships};
	return $params;
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

sub transportedReactants {
    my $self = shift @_;
    return [ grep { $_->compartmentIndex > 0 } @{$self->reactants} ];
}

sub _buildDbAttributes {
    return [qw( uuid modDate locked id name abbreviation cksum
    equation deltaG deltaGErr reversibility thermoReversibility
    defaultProtons compartment_uuid defaultTransproton )];
}

sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now(); }
sub _buildEquation {
    my $self = shift @_;
    my $reactants = [sort grep { $_->{coefficient} < 0 } @{$self->reactants}];
    my $products  = [sort grep { $_->{coefficient} > 0 } @{$self->reactants}];
    my $eqStr = [];
    foreach my $side ($reactants, $products) {
        my $eq = [];
        foreach my $side (@$side) {
            my $str   = "";
            my $coff  = $side->{coefficient};
            my $name  = $side->{compound}->name;
            my $index = $side->{compartmentIndex};
            $str .= "($coff) " if abs($coff) > 1;
            $str .= $name;
            $str .= "[$index]" if $index > 0;
            push(@$eq, $str);
        }
        push(@$eqStr, join(" + ", @$eq));
    }
    return join($self->reversibility, @$eqStr);
}

__PACKAGE__->meta->make_immutable;
1;
