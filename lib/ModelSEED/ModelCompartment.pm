package ModelSEED::ModelCompartment;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::ModelCompartment' },
     );

1;
