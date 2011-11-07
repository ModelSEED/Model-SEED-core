#!/usr/bin/perl -w

########################################################################
# This is the TOP LEVEL API for the Model SEED system, providing all functions available on the command line interface in serialized form
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/5/2011
########################################################################
use strict;
use ModelSEED::FIGMODEL;
package ModelSEED::msapi;
=head3 new
Definition:
	driver = driver->new();
Description:
	Returns a driver object
=cut
sub new { 
	my $self = {_figmodel => ModelSEED::FIGMODEL->new()};
    return bless $self;
}
=head3 figmodel
Definition:
	FIGMODEL = driver->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}
=head3 db
Definition:
	FIGMODEL = driver->db();
Description:
	Returns a database object
=cut
sub db {
	my ($self) = @_;
	return $self->figmodel()->database();
}
=head3 config
Definition:
	{}/[] = driver->config(string);
Description:
	Returns a requested configuration object
=cut
sub config {
	my ($self,$key) = @_;
	return $self->figmodel()->config($key);
}         
=CATEGORY
Biochemistry Operations
=SHORTDESCRIPTION
print Model SEED media formulation
=DESCRIPTION
This function is used to print a media formulation to the current workspace.
=ARGUMENTS
media:ID of the media formulation to be printed:mandatory
=EXAMPLE
./bcprintmedia -media Carbon-D-glucose
=cut
sub bcprintmedia {
    my($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["media"],{});
	return $self->figmodel()->buildObject("media",{id => $args->{media}})
}

1;
