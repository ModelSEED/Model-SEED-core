########################################################################
# ModelSEED::MooseDB::mediacpd - This is the moose object corresponding to the link between media and compounds in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::globals;

package ModelSEED::MooseDB::mediacpd;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use MooseX::Storage;

extends 'ModelSEED::MooseDB::object';

#with Storage('format' => 'JSON', 'io' => 'File'); 
#Other formats include Storable and YAML
#Other io include AtomicFile and StorableFile

has 'MEDIA' => (is => 'ro', isa => 'Str', required => 1, metaclass => 'DoNotSerialize');
has 'entity' => (is => 'ro', isa => 'Str', required => 1, index => 0, metaclass => 'Indexed');
has 'type' => (is => 'ro', isa => 'Str', required => 1, index => 1, metaclass => 'Indexed');
has 'concentration' => (is => 'ro', isa => 'Num', required => 1, index => 2, metaclass => 'Indexed');
has 'maxFlux' => (is => 'ro', isa => 'Int', required => 1, index => 3, metaclass => 'Indexed');
has 'minFlux' => (is => 'ro', isa => 'Int', required => 1, index => 4, metaclass => 'Indexed');

sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::globals::ARGS($params,[],{});
}

1;