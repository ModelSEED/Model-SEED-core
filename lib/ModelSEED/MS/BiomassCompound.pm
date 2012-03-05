########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the ModelReaction object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::ModelCompartment;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Model;
package ModelSEED::MS::BiomassCompound;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has model => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);

#Attributes
has biomass_uuid => (is => 'rw', isa => 'Str', required => 1);
has compound_uuid => (is => 'rw', isa => 'Str', required => 1);
has model_compartment_uuid => (is => 'rw', isa => 'Str', required => 1);
has coefficient => (is => 'rw', isa => 'Num', required => 1);

#Subobjects
has compound => (is => 'rw',isa => 'ModelSEED::MS::Compound',lazy => 1,builder => '_getCompound');
has compartment => (is => 'rw',isa => 'ModelSEED::MS::ModelCompartment',lazy => 1,builder => '_getCompartment');

#Constants
has 'dbAttributes' => (is => 'ro',isa => 'ArrayRef[Str]',builder => '_buildDbAttributes');
has '_type' => (is => 'ro', isa => 'Str',default => "BiomassCompound");

sub BUILDARGS {
    my ($self,$params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    # Set up attributes
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    # Set up relationships
    if(defined($rels)) {
        print "biomass compound relations:".join("|",keys(%{$rels}))."\n";
    }
    delete $params->{relationships};
	return $params;
}

sub serializeToDB {
    my ($self) = @_;
	my $data = {};
	my $attributes = $self->dbAttributes();
	for (my $i=0; $i < @{$attributes}; $i++) {
		my $function = $attributes->[$i];
		$data->{attributes}->{$function} = $self->$function();
	}
	return $data;
}

sub _getCompound {
	my ($self) = @_;
	if (defined($self->model())) {
        my $rxn = $self->model()->biochemistry()->getCompound({uuid => $self->compound_uuid});
        if (!defined($rxn)) {
        	ModelSEED::utilities::ERROR("Model compound ".$self->compound_uuid." not found in model biochemistry!");
        }
        return $rxn;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve compound without model and biochemistry objects!");
    }	
}

sub _getCompartment {
	my ($self) = @_;
	if (defined($self->model())) {
        my $cmp = $self->model()->getModelCompartment({uuid => $self->model_compartment_uuid});
        if (!defined($cmp)) {
        	ModelSEED::utilities::ERROR("Model compartment ".$self->model_compartment_uuid." not found in model!");
        }
        return $cmp;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve compartment without model object!");
    }	
}

sub _buildDbAttributes { return [qw( biomass_uuid  compound_uuid model_compartment_uuid coefficient )]; }

__PACKAGE__->meta->make_immutable;
1;
