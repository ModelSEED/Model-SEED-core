########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::globals;

use ModelSEED::MooseDB::mediacpd;
package ModelSEED::MooseDB::media;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use MooseX::Storage;

extends 'ModelSEED::MooseDB::object';

#with Storage('format' => 'JSON', 'io' => 'File'); 
#Other formats include Storable and YAML
#Other io include AtomicFile and StorableFile

has 'id' => (is => 'ro', isa => 'Str', required => 1, index => 0, metaclass => 'Indexed');
has 'owner' => (is => 'ro', isa => 'Str', required => 1, metaclass => 'DoNotSerialize');
has 'modificationDate' => (is => 'ro', isa => 'Int', required => 1, metaclass => 'DoNotSerialize');
has 'creationDate' => (is => 'ro', isa => 'Int', required => 1, metaclass => 'DoNotSerialize');
has 'aliases' => (is => 'ro', isa => 'Str', required => 1, default => "", index => 1, metaclass => 'Indexed');
has 'aerobic' => (is => 'ro', isa => 'Bool', required => 1, metaclass => 'DoNotSerialize');
has 'public' => (is => 'ro', isa => 'Bool', required => 1, metaclass => 'DoNotSerialize');
has 'mediaCompounds' => (is => 'ro', isa => 'ArrayRef[ModelSEED::MooseDB::mediacpd]', lazy => 1, builder => '_build_mediaCompounds', index => 2, metaclass => 'Indexed');

sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::globals::ARGS($params,[],{});
}

sub _build_mediaCompounds {
    my ($self) = @_;
    return $self->db()->get_moose_objects("mediacpd",{MEDIA => $self->id()});
}

1;
