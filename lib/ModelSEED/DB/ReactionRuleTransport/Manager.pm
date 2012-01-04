package ModelSEED::DB::ReactionRuleTransport::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReactionRuleTransport;

sub object_class { 'ModelSEED::DB::ReactionRuleTransport' }

__PACKAGE__->make_manager_methods('reaction_rule_transports');

1;

