package ModelSEED::DB::AnnotationFeature::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::AnnotationFeature;

sub object_class { 'ModelSEED::DB::AnnotationFeature' }

__PACKAGE__->make_manager_methods('annotation_features');

1;

