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
package ModelSEED::MS::Media;
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
has 'type' => (is => 'ro', isa => 'Str', required => 1);
#Subobjects
has 'compounds' => (is => 'ro', isa => 'HashRef', required => 1,default => sub{{}});

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
		if (defined($params->{rawdata}->{relations}->{media_compounds})) {
			foreach my $mediacpd (@{$params->{rawdata}->{relations}->{media_compounds}}) {
				$params->{compounds}->{$mediacpd->{attributes}->{compound_uuid}} = {
					minflux => $mediacpd->{attributes}->{minflux},
					maxflux => $mediacpd->{attributes}->{maxflux},
					concentraion => $mediacpd->{attributes}->{concentraion}
				};
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