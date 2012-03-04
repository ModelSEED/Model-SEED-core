########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the ModelReaction object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::ModelCompartment;
package ModelSEED::MS::ModelReaction;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has model => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);

#Attributes
has reaction_uuid     => (is => 'rw', isa => 'Str', default  => "");
has model_compartment_uuid     => (is => 'rw', isa => 'Str', default  => "");
has direction     => (is => 'rw', isa => 'Str', default  => "");
has transproton    => (is => 'rw', isa => 'Num');
has protons   => (is => 'rw', isa => 'Num');

#Subobjects
has gpr   => (is => 'rw', isa => 'ArrayRef[Str]');
has reaction => (
	is      => 'rw',
    isa     => 'Maybe[ModelSEED::MS::Reaction]',
    lazy   => 1,
    builder => '_getReaction'
);
has compartment => (
	is      => 'rw',
    isa     => 'Maybe[ModelSEED::MS::ModelCompartment]',
    lazy   => 1,
    builder => '_getCompartment'
);

#Computed attributes
has equation => (is => 'rw',isa => 'Str',lazy => 1,builder => '_buildEquation');

#Constants
has 'dbAttributes' => ( is => 'ro', isa => 'ArrayRef[Str]', 
    builder => '_buildDbAttributes' );
has 'dbType' => (is => 'ro', isa => 'Str',default => "Reaction");

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
        #print "mdlrxn relations:".join("|",keys(%{$rels}))."\n";
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

sub _getReaction {
	my ($self) = @_;
	if (defined($self->model())) {
        my $rxn = $self->model()->biochemistry()->getReaction({uuid => $self->reaction_uuid});
        if (!defined($rxn)) {
        	ModelSEED::utilities::ERROR("Model reaction ".$self->reaction_uuid." not found in model biochemistry!");
        }
        return $rxn;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve reaction without model and biochemistry objects!");
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

sub _buildEquation {
	#TODO
	my $equation = "NONE";
	return $equation;
}

sub _buildDbAttributes { return [qw( reaction_uuid  model_compartment_uuid direction transproton)]; }

__PACKAGE__->meta->make_immutable;
1;
