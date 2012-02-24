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
has 'uuid' => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has 'modDate' => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has 'id' => (is => 'rw', isa => 'Str', required => 1);
has 'locked' => (is => 'rw', isa => 'Int', default => 0);
has 'name' => (is => 'rw', isa => 'Str', default => '');
has 'abbreviation' => (is => 'rw', isa => 'Str', default => '');
has 'cksum' => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildCksum');
has 'unchargedFormula' => (is => 'rw', isa => 'Str');
has 'formula' => (is => 'rw', isa => 'Str');
has 'mass' => (is => 'rw', isa => 'Str');
has 'defaultCharge' => (is => 'rw', isa => 'Str');
has 'deltaG' => (is => 'rw', isa => 'Str');
has 'deltaGErr' => (is => 'rw', isa => 'Str');
#Subobjects
has 'aliases' => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; });
has 'structures' => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; });
has 'pk' => (is => 'rw', isa => 'HashRef');
#Constants
has 'dbAttributes' => ( is => 'ro', isa => 'ArrayRef[Str]',
    builder => '_buildDbAttributes' );
has 'dbType' => (is => 'ro', isa => 'Str',default => "Compound");
#Internally maintained variables
has 'changed' => (is => 'rw', isa => 'Bool',default => 0);

sub BUILDARGS {
    my ($self,$params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    if(defined($rels)) {
        foreach my $alias (@{$rels->{aliases} || []}) {
            push(@{$params->{aliases}}, {
                type => $alias->{attributes}->{type},
                alais => $alias->{attributes}->{alias},
            });
        }
        foreach my $structure (@{$rels->{compound_structures} || []}) {
            push(@{$params->{compound_structures}}, {
                type => $structure->{attributes}->{type},
                structure => $structure->{attributes}->{structure},
                modDate => $structure->{attributes}->{modDate},
                cksum => $structure->{attributes}->{cksum}
            });
        }
        my $pk_attr = $rels->{compound_pk}->{attributes};
        if(defined($pk_attr)) {
            $params->{compound_pk} = {
                type => $pk_attr->{type},
                structure => $pk_attr->{structure},
                modDate => $pk_attr->{modDate},
                cksum => $pk_attr->{cksum}
            };
        }
        delete $params->{relationships}
    }
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

sub _buildDbAttributes {
    return [qw( uuid modDate locked id name abbreviation cksum
    unchargedFormula formula mass defaultCharge deltaG deltaGErr )];
}


__PACKAGE__->meta->make_immutable;
1;
