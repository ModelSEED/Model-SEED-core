package ModelSEED::BiochemistryMedia;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::BiochemistryMedia' },
     );

1;
