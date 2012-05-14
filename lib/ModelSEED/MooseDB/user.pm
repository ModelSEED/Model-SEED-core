########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::globals;
package ModelSEED::MooseDB::user;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

extends 'ModelSEED::MooseDB::object';

has 'email' => (is => 'ro', isa => 'Str', required => 1, default => "");
has 'login' => (is => 'ro', isa => 'Str', required => 1);
has 'password' => (is => 'ro', isa => 'Str', required => 1);
has 'firstname' => (is => 'ro', isa => 'Str', required => 1, default => "");
has 'lastname' => (is => 'ro', isa => 'Str', required => 1, default => "");

sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{});
}

1;
