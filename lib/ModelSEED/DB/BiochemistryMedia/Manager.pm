package ModelSEED::DB::BiochemistryMedia::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryMedia;

sub object_class { 'ModelSEED::DB::BiochemistryMedia' }

__PACKAGE__->make_manager_methods('biochemistry_media');

1;

