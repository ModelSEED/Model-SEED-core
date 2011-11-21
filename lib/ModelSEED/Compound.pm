package ModelSEED::Compound;
use Moose;
use ModelSEED::Role::DBObject;

with 'ModelSEED::Role::DBObject' => {
        rose_class => "ModelSEED::DB::Compound",
        attribute_roles => {
            'uuid' => 'ModelSEED::Role::UUID',
            'modDate' => 'ModelSEED::Role::ModDate'
        },
    };

1;
