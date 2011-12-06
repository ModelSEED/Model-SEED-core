package ModelSEED::RolesetParents;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::RolesetParents' },
     );

1;
