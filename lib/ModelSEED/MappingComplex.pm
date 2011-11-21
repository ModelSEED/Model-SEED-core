package ModelSEED::MappingComplex;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::MappingComplex' },
     );

1;
