package ModelSEED::DB::BiomassCompound::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiomassCompound;

sub object_class { 'ModelSEED::DB::BiomassCompound' }

__PACKAGE__->make_manager_methods('biomass_compounds');

1;

