package ModelSEED::AnnotationParents;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::AnnotationParents' },
     );

1;
