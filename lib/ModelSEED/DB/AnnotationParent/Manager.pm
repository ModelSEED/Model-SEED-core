package ModelSEED::DB::AnnotationParent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::AnnotationParent;

sub object_class { 'ModelSEED::DB::AnnotationParent' }

__PACKAGE__->make_manager_methods('annotation_parents');

1;

