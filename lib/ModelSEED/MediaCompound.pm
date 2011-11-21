package ModelSEED::MediaCompound;
use Moose;
use ModelSEED::Role::DBObject;

with ('ModelSEED::Role::DBObject' =>
        { rose_class => "ModelSEED::DB::MediaCompound" },
     );

1;
