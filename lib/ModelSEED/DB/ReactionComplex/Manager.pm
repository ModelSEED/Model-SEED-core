package ModelSEED::DB::ReactionComplex::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReactionComplex;

sub object_class { 'ModelSEED::DB::ReactionComplex' }

__PACKAGE__->make_manager_methods('reaction_complex');

1;

