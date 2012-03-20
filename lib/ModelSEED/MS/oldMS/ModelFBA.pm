########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the ModelReaction object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Media;
use ModelSEED::MS::Model;
package ModelSEED::MS::ModelFBA;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has model => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);

#Attributes
has uuid    => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has locked => (is => 'rw',isa => 'Int',default => 0);
has model_uuid => (is => 'rw',isa => 'Str',required => 1);
has media_uuid => (is => 'rw',isa => 'Str',required => 1);
has options => (is => 'rw',isa => 'Str',required => 1);
has geneko => (is => 'rw',isa => 'Str',default => '');
has reactionko => (is => 'rw',isa => 'Str',default => '');

#Subobjects
has media => (is => 'rw',isa => 'ModelSEED::MS::Media',lazy => 1,builder => '_getMedia');

#Constants
has 'dbAttributes' => (is => 'ro',isa => 'ArrayRef[Str]',builder => '_buildDbAttributes');
has '_type' => (is => 'ro', isa => 'Str',default => "ModelFBA");

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
        print "Model FBA relations:".join("|",keys(%{$rels}))."\n";
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

sub _getMedia {
	my ($self) = @_;
	if (defined($self->model())) {
        my $media = $self->model()->biochemistry()->getMedia({uuid => $self->media_uuid});
        if (!defined($media)) {
        	ModelSEED::utilities::ERROR("Media ".$self->media_uuid." not found in biochemistry!");
        }
        return $media;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve compartment without model object!");
    }
}

sub _buildID {
	my ($self) = @_;
	return $self->compartment()->id().$self->compartmentIndex();
}
sub _buildDbAttributes { return [qw( uuid  model_uuid media_uuid options geneko reactionko modDate locked )]; }
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }

__PACKAGE__->meta->make_immutable;
1;
