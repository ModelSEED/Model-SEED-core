package ModelSEED::BiochemistryReactionAlia;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::BiochemistryReactionAlia' },
     );

1;
