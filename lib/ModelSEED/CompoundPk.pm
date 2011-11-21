package ModelSEED::CompoundPk;
use Moose;
use ModelSEED::Role::DBObject;

with ( 'ModelSEED::Role::DBObject' => { rose_class => "ModelSEED::DB::CompoundPk"} );

1;
