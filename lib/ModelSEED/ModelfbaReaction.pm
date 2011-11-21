package ModelSEED::ModelfbaReaction;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::ModelfbaReaction' },
     );

1;
