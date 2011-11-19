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

sub BUILDARGS {
	my ($self,$params) = @_;
	$params->{type} => "mediacpd";
	if (defined($params->{filedata})) {
		$params = $self->parse($params);
	}
	return $params;
}

sub print {
	my ($self) = @_;
	my $data = [
		"MEDIA\t".$self->MEDIA(),
		"entity\t".$self->entity(),
		"type\t".$self->type(),
		"concentration\t".$self->concentration(),
		"maxFlux\t".$self->maxFlux(),
		"minFlux\t".$self->minFlux()
	];
	return $data;
}

sub parse {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["filedata"],{});
	for (my $i=0; $i < @{$args->{filedata}}; $i++) {
		my $array = split(/\t/,$args->{filedata}->[$i]);
		my $function = $array->[0];
		if ($function eq "MEDIA" || $function eq "entity" || $function eq "type" || $function eq "concentration" || $function eq "maxFlux" || $function eq "minFlux") {
			$params->{$function} = $array->[1];
		}
	}
	return $params;
}


1;