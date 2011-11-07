########################################################################
# ModelSEED::MooseDB::object - This is the base level object for all MooseDB and higher level entities in Model SEED
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::globals;

package MyApp::Meta::Attribute::Indexed;
use Moose;
extends 'Moose::Meta::Attribute';

has index => (
      is        => 'ro',
      isa       => 'Int',
      predicate => 'has_index',
);

package Moose::Meta::Attribute::Custom::Indexed;
sub register_implementation { 'MyApp::Meta::Attribute::Indexed' }

package ModelSEED::MooseDB::object;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use MooseX::Storage;

our $VERSION = '1';

with Storage('format' => 'YAML', 'io' => 'File'); 
#Other formats include Storable and YAML
#Other io include AtomicFile and StorableFile

#Maybe link to DB with:
#MooseX::Types::DBIx::Class
#DBIx::Class

has 'db' => (is => 'ro', isa => 'ModelSEED::FIGMODEL::FIGMODELdatabase', required => 1, metaclass => 'DoNotSerialize');

sub BUILDARGS {
	my ($self,$params) = @_;
	if (defined($params->{ppo})) {
		my $attributes = $params->{ppo}->attributes();
		foreach my $attribute (keys(%{$attributes})) {
			$params->{$attribute} = $params->{ppo}->$attribute();
			if (!defined($params->{$attribute})) {
				delete $params->{$attribute};
			}
		}
	}
	return $params;
}

sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::globals::ARGS($params,[],{});
}


around 'pack' => sub {
	my $orig = shift;
	my $self = shift;
	my $data = $self->$orig();
	my $attributes = [$self->meta()->get_attribute_list()];
	foreach my $attribute (@{$attributes}) {
		my $att = $self->meta()->get_attribute($attribute);
		if ($att->isa('MyApp::Meta::Attribute::Indexed') && $att->has_index ) {
        	$data->{attributes}->{$attribute} = $att->index();
		}
	}
	return $data;
};

1;
