package ModelSEED::ReactionComplex;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::ReactionComplex' },
     );

1;
