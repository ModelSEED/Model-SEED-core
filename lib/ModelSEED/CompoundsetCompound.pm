package ModelSEED::CompoundsetCompound;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::CompoundsetCompound' },
     );

1;
