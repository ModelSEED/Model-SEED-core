package ModelSEED::DB::Biochemistry::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Biochemistry;

sub object_class { 'ModelSEED::DB::Biochemistry' }

__PACKAGE__->make_manager_methods('biochemistry');

1;

