package ModelSEED::MappingCompartment;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::MappingCompartment' },
     );

1;
