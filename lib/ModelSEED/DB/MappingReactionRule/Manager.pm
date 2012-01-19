package ModelSEED::DB::MappingReactionRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MappingReactionRule;

sub object_class { 'ModelSEED::DB::MappingReactionRule' }

__PACKAGE__->make_manager_methods('mapping_reaction_rules');

1;

