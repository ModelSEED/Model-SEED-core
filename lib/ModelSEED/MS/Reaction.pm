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
use ModelSEED::MS::Compartment;
package ModelSEED::MS::Reaction;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Attributes
has 'uuid'     => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has 'modDate'  => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has 'id'       => (is => 'rw', isa => 'Str', required => 1);
has 'locked'   => (is => 'rw', isa => 'Int', default  => 0);
has 'name'     => (is => 'rw', isa => 'Str', default  => "");
has 'cksum'    => (is => 'rw', isa => 'Str');
has 'deltaG'   => (is => 'rw', isa => 'Str');
has 'equation' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_buildEquation');
has 'deltaGErr'           => (is => 'rw', isa => 'Str');
has 'abbreviation'        => (is => 'rw', isa => 'Str');
has 'compartment_uuid'    => (is => 'rw', isa => 'Str', required => 1);
has 'defaultTransproton'  => (is => 'rw', isa => 'Num', default => 0);
has 'defaultProtons'      => (is => 'rw', isa => 'Num', default => 0);
has 'reversibility'       => (is => 'rw', isa => 'Str', default => '=');
has 'thermoReversibility' => (is => 'rw', isa => 'Str');

#Subobjects
has 'aliases' => (is => 'rw', isa => 'HashRef', default => sub { return {}; });
has 'reagents' => (is => 'rw', isa => 'ArrayRef', default => sub { return []; });
has 'transported' => (is => 'rw', isa => 'ArrayRef', default => sub { return []; });
has 'compartment' => (
    is      => 'rw',
    isa     => 'Maybe[ModelSEED::MS::Compartment]',
    lazy   => 1,
    builder => '_getCompartment'
);

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
    # Set up attributes
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    # Set up relationships
    if(defined($rels)) {
        # Set up aliases
        if (defined($rels->{aliases})) {
	        foreach my $alias (@{$rels->{aliases}}) {
	        	if (defined($alias->{attributes}->{type}) && defined($alias->{attributes}->{alias})) {
	            	push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
	        	}
	        }
    	}
        my ($reagents, $transported) = ([], []);
		foreach my $reagent (@{$rels->{reagents}}) {
            my $cpd;
            my $id = $reagent->{attributes}->{compound_uuid};
            if (defined($bio)) {
                $cpd = $bio->getCompound({uuid => $id});
                die "Unknown compound: $id" unless(defined($cpd));
            }
			if ($reagent->{attributes}->{compartmentIndex} == 0) {
                    my $hash = {
						coefficient => $reagent->{attributes}->{coefficient},
                        compound_uuid => $id,
						cofactor => $reagent->{attributes}->{cofactor}
					};
                    $hash->{compound} = $cpd if(defined($cpd));
                    push(@$reagents, $hash);
			} else {
                my $hash = {
                    compartment => $reagent->{attributes}->{compartmentIndex},
                    coefficient => $reagent->{attributes}->{coefficient},
                    compound_uuid => $id,
                    cofactor => $reagent->{attributes}->{cofactor}
                };
                $hash->{compound} = $cpd if(defined($cpd));
                push(@$transported, $hash);
			}
		}
        $params->{reagents} = $reagents;
        $params->{transported} = $transported;
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
	$data->{relationships}->{aliases} = [];
	foreach my $aliastype (sort keys(%{$self->aliases()})) {
		foreach my $alias (sort @{$self->aliases()->{$aliastype}}) {
			push(@{$data->{relationships}->{aliases}},{
				type => "ReactionAlias",
				attributes => {
					reaction_uuid => $self->uuid(),
					alias => $alias,
					type => $aliastype
				}
			});
		}
	}
	$data->{relationships}->{reagents} = [];
    foreach my $reactant (
        sort { $a->{compound_uuid} cmp $b->{compound_uuid} }
        @{$self->reagents}
        ) {
		push(@{$data->{relationships}->{reagents}},{
			type => "Reagent",
			attributes => {
				reaction_uuid => $self->uuid(),
				compound_uuid => $reactant->{compound_uuid},
				compartmentIndex => 0,
				coefficient => $reactant->{coefficient},
				cofactor => $reactant->{cofactor}
			}					
		});
	}
	foreach my $reactant (
        sort { $a->{compound_uuid} cmp $b->{compound_uuid} }
        @{$self->transported}
    ) {
		push(@{$data->{relationships}->{reagents}},{
			type => "Reagent",
			attributes => {
				reaction_uuid => $self->uuid(),
				compound_uuid => $reactant->{compound_uuid},
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
    return [ grep { $_->compartmentIndex > 0 } @{$self->reagents} ];
}

sub _buildDbAttributes {
    return [qw( uuid id  name abbreviation equation deltaG deltaGErr
       reversibility thermoReversibility
    defaultProtons compartment_uuid defaultTransproton modDate locked cksum)];
}

sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now(); }
sub _buildEquation {
    my $self = shift @_;
    my $reactants = [sort grep { $_->{coefficient} < 0 } @{$self->reagents}];
    my $products  = [sort grep { $_->{coefficient} > 0 } @{$self->reagents}];
    my $eqStr = [];
    foreach my $side ($reactants, $products) {
        my $eq = [];
        foreach my $side (@$side) {
            my $str   = "";
            my $coff  = $side->{coefficient};
            my $name  = (defined($side->{compound})) ?
                $side->{compound}->name : $side->{compound_uuid};
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
sub updateChecksum {
    my $self = shift @_;
    my $reactants = [sort grep { $_->{coefficient} < 0 } @{$self->reagents}];
    my $products  = [sort grep { $_->{coefficient} > 0 } @{$self->reagents}];
    $reactants = [ map { $_->cksum } sort { $a->cksum cmp $b->cksum } @$reactants ];
    $products = [ map { $_->cksum } sort { $a->cksum cmp $b->cksum } @$products ];
    $self->cksum(md5_hex( 
        $self->compartment->uuid .
        join("", (@$reactants, @$products))
    ));
    return $self->cksum;
}
sub _getCompartment {
    my ($self) = @_;
    die "No Biochemistry" unless defined $self->biochemistry;
    return $self->biochemistry->getCompartment({ uuid => $self->compartment_uuid });
}

__PACKAGE__->meta->make_immutable;
1;
