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
use Data::UUID;
use DateTime;
use Digest::MD5 qw(md5_hex);
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
has 'formula' => (is => 'rw', isa => 'Str', default => '');
has 'mass' => (is => 'rw', isa => 'Num');
has 'defaultCharge' => (is => 'rw', isa => 'Num');
has 'deltaG' => (is => 'rw', isa => 'Num');
has 'deltaGErr' => (is => 'rw', isa => 'Num');
#Subobjects
has 'aliases' => (is => 'rw', isa => 'HashRef', default => sub { return {}; });
has 'structures' => (is => 'rw', isa => 'HashRef', default => sub { return {}; });
has 'pKs' => (is => 'rw', isa => 'ArrayRef', default => sub { return []; });
has 'compoundSets' => (is => 'rw', isa => 'HashRef', default => sub { return {}; });
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
            push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
        }
        foreach my $structure (@{$rels->{compound_structures} || []}) {
            push(@{$params->{structures}->{$structure->{attributes}->{type}}},{
            	structure => $structure->{attributes}->{structure},
                modDate => $structure->{attributes}->{modDate},
                cksum => $structure->{attributes}->{cksum}
            });
        }
        foreach my $pk (@{$rels->{compound_pk} || []}) {
            push(@{$params->{pk}->{$pk->{attributes}->{type}}},{
            	atom => $pk->{attributes}->{atom},
                pk => $pk->{attributes}->{pk},
            });
        }
        delete $params->{relationships};
    }
    return $params;
}

sub addSet {
    my ($self,$set) = @_;
	push(@{$self->compoundSets()->{$set->type()}},$set);
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
	$data->{relationships}->{compound_aliases} = [];
	foreach my $aliastype (keys(%{$self->aliases()})) {
		foreach my $alias (@{$self->aliases()->{$aliastype}}) {
			push(@{$data->{relationships}->{compound_aliases}},{
				type => "CompoundAlias",
				attributes => {
					compound_uuid => $self->uuid(),
					alias => $alias,
					type => $aliastype
				}
			});
		}
	}
	$data->{relationships}->{compound_structures} = [];
	foreach my $structureType (keys(%{$self->structures()})) {
		if ($structureType !~ m/cksum$/) {
			push(@{$data->{relationships}->{compound_structures}},{
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
	$data->{relationships}->{compound_pk} = [];
	foreach my $pk (@{$self->pKs()}) {
		push(@{$data->{relationships}->{compound_pk}},{
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

sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now(); }
sub _buildCksum {
    my ($self) = @_;
    return md5_hex($self->id
            . $self->name
            . $self->formula);
}

__PACKAGE__->meta->make_immutable;
1;
