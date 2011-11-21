package ModelSEED::DB::DB::Object::AutoBase2;

use base 'Rose::DB::Object';

use ModelSEED::DB::DB::AutoBase1;

sub init_db { ModelSEED::DB::DB::AutoBase1->new_or_cached }

1;
