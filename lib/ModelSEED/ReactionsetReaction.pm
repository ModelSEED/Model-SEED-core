package ModelSEED::ReactionsetReaction;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::ReactionsetReaction' },
     );

1;
