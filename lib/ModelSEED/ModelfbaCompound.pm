package ModelSEED::ModelfbaCompound;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::ModelfbaCompound' },
     );

1;
