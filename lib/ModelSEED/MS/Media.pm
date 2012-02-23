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
package ModelSEED::MS::Media;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

#Attributes
has 'uuid' => (is => 'ro', isa => 'Str', required => 1);
has 'modDate' => (is => 'ro', isa => 'Str', required => 1);
has 'id' => (is => 'ro', isa => 'Str', required => 1);
has 'locked' => (is => 'ro', isa => 'Int', required => 1);
has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'type' => (is => 'ro', isa => 'Str', required => 1);
#Subobjects
has 'compounds' => (is => 'ro', isa => 'ArrayRef[ModelSEED::MS::Compound]',required => 1,default => sub{[]});
has 'concentrations' => (is => 'ro', isa => 'ArrayRef[Num]',required => 1,default => sub{[]});
has 'maxFluxes' => (is => 'ro', isa => 'ArrayRef[Num]',required => 1,default => sub{[]});
has 'minFluxes' => (is => 'ro', isa => 'ArrayRef[Num]',required => 1,default => sub{[]});
#Constants
has 'dbAttributes' => (is => 'ro', isa => 'ArrayRef[Str]',default => ["uuid","modDate","locked","id","name","type"]);
has 'dbType' => (is => 'ro', isa => 'Str',default => "Media");

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
				my $cpd = $params->{biochemistry}->getCompound({attribute => "uuid",value => $mediacpd->{attributes}->{compound_uuid}});
				if (!defined($cpd)) {
					ModelSEED::utilities::ERROR("Could not find media compound ".$mediacpd->{attributes}->{compound_uuid}." in parent biochemistry!");	
				}
				push(@{$params->{compounds}},$cpd);
				push(@{$params->{concentrations}},$mediacpd->{attributes}->{concentraion});
				push(@{$params->{maxFluxes}},$mediacpd->{attributes}->{maxflux});
				push(@{$params->{minFluxes}},$mediacpd->{attributes}->{minflux});
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
	$data->{relations}->{MediaCompound} = [];
	my $compounds = $self->compounds();
	for (my $i=0; $i < @{$compounds}; $i++) {
		push(@{$data->{relations}->{MediaCompound}},{
			type => "MediaCompound",
			attributes => {
				media_uuid => $self->uuid(),
				compound_uuid => $compounds->[$i]->uuid(),
				concentration => $self->concentrations()->[$i],
				minflux => $self->minFluxes()->[$i],
				maxflux => $self->maxFluxes()->[$i]
			},
			relations => {}
		});
	}	
	return $data;
}

__PACKAGE__->meta->make_immutable;
1;