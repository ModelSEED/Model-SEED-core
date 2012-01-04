package ModelSEED::DB::Genome::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Genome;

sub object_class { 'ModelSEED::DB::Genome' }

__PACKAGE__->make_manager_methods('genomes');

1;

