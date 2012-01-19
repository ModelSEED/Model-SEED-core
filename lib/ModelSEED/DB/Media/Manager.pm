package ModelSEED::DB::Media::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Media;

sub object_class { 'ModelSEED::DB::Media' }

__PACKAGE__->make_manager_methods('media');

1;

