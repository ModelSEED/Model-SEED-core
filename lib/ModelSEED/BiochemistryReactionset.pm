package ModelSEED::BiochemistryReactionset;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::BiochemistryReactionset' },
     );

1;
