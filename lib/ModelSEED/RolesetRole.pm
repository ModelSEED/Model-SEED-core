package ModelSEED::RolesetRole;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => 
        { rose_class => 'ModelSEED::DB::RolesetRole' },
     );

1;
