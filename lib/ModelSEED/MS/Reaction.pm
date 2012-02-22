########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Biochemistry;
package ModelSEED::MS::Reaction;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

#Attributes
has 'biochemistry' => (is => 'ro', isa => 'ModelSEED::MS::Biochemistry', required => 1);
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
has 'reagents' => (is => 'ro', isa => 'HashArray', required => 1,default => sub{{
	reactants => {},
	products => {},
	imported => {},
	exported => {},
}});

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
			foreach my $set (@{$params->{rawdata}->{relations}->{reactionsets}}) {
				push(@{$params->{sets}->{$set->{attributes}->{type}}},$set->{attributes}->{uuid});
			}
		}
		if (defined($params->{rawdata}->{relations}->{aliases})) {
			foreach my $alias (@{$params->{rawdata}->{relations}->{aliases}}) {
				push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
			}
		}
		if (defined($params->{rawdata}->{relations}->{reagents})) {
			foreach my $reagent (@{$params->{rawdata}->{relations}->{reagents}}) {
				if ($reagent->{attributes}->{compartmentIndex} == 0) {
					if ($reagent->{attributes}->{coefficient} < 0) {
						$params->{reagents}->{reactants}->{$reagent->{attributes}->{compound_uuid}} = $reagent->{attributes}->{coefficient};
					} elsif ($reagent->{attributes}->{coefficient} > 0) {
						$params->{reagents}->{products}->{$reagent->{attributes}->{compound_uuid}} = $reagent->{attributes}->{coefficient};
					}
				} else {
					if ($reagent->{attributes}->{coefficient} < 0) {
						$params->{reagents}->{exported}->{$reagent->{attributes}->{compartmentIndex}}->{$reagent->{attributes}->{compound_uuid}} = $reagent->{attributes}->{coefficient};
					} elsif ($reagent->{attributes}->{coefficient} > 0) {
						$params->{reagents}->{imported}->{$reagent->{attributes}->{compartmentIndex}}->{$reagent->{attributes}->{compound_uuid}} = -1*$reagent->{attributes}->{coefficient};	
					}	
				}
			}
		}
	}
	return $params;
}

sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{});
}

__PACKAGE__->meta->make_immutable;
1;