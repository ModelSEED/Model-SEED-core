package ModelSEED::CompoundAlias;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::CompoundAlias' },
     );

1;
