package ModelSEED::BiochemistryParents;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::BiochemistryParents' },
     );

1;
