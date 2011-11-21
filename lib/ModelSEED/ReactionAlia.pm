package ModelSEED::ReactionAlia;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::ReactionAlia' },
     );

1;
