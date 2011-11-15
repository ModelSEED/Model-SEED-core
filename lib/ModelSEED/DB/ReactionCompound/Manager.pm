package ModelSEED::DB::ReactionCompound::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReactionCompound;

sub object_class { 'ModelSEED::DB::ReactionCompound' }

__PACKAGE__->make_manager_methods('reaction_compound');

1;

