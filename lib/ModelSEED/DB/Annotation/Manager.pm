package ModelSEED::DB::Annotation::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Annotation;

sub object_class { 'ModelSEED::DB::Annotation' }

__PACKAGE__->make_manager_methods('annotations');

1;

