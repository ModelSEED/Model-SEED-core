package ModelSEED::BiochemistryReaction;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::BiochemistryReaction' },
     );

1;
