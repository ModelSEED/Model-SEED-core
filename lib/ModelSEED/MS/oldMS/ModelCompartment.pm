########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the ModelReaction object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Model;
package ModelSEED::MS::ModelCompartment;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has model => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);

#Attributes
has id    => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildID');
has uuid    => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has locked => (is => 'rw',isa => 'Int',default => 0);
has model_uuid => (is => 'rw',isa => 'Str',required => 1);
has compartment_uuid => (is => 'rw',isa => 'Str',required => 1);
has compartmentIndex => (is => 'rw',isa => 'Str',required => 1);
has label => (is => 'rw',isa => 'Str',default => '');
has pH => (is => 'rw',isa => 'Num',default => 7);
has potential => (is => 'rw',isa => 'Num',default => 0);

#Subobjects
has compartment => (is => 'rw',isa => 'ModelSEED::MS::Compartment',lazy => 1,builder => '_getCompartment');

#Constants
has 'dbAttributes' => (is => 'ro',isa => 'ArrayRef[Str]',builder => '_buildDbAttributes');
has '_type' => (is => 'ro', isa => 'Str',default => "ModelCompartment");

sub BUILDARGS {
    my ($self,$params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    # Set up attributes
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
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

sub _getCompartment {
	my ($self) = @_;
	if (defined($self->model())) {
        my $cmp = $self->model()->biochemistry()->getCompartment({uuid => $self->compartment_uuid});
        if (!defined($cmp)) {
        	ModelSEED::utilities::ERROR("Compartment ".$self->compartment_uuid." not found in biochemistry!");
        }
        return $cmp;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve compartment without model object!");
    }
}

sub _buildID { 
	my ($self) = @_;
	return $self->compartment()->id().$self->compartmentIndex();
}
sub _buildDbAttributes { return [qw( uuid  model_uuid compartment_uuid compartmentIndex label pH potential modDate locked )]; }
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }

__PACKAGE__->meta->make_immutable;
1;
