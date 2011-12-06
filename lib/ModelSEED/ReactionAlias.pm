package ModelSEED::ReactionAlias;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::ReactionAlias' },
     );

1;
