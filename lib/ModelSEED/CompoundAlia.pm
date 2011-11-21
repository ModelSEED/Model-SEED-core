package ModelSEED::CompoundAlia;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::CompoundAlia' },
     );

1;
