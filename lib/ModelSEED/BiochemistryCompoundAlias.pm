package ModelSEED::BiochemistryCompoundAlias;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::BiochemistryCompoundAlias' },
     );

1;
