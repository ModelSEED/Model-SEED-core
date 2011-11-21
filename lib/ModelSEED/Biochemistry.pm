package ModelSEED::Biochemistry;
use Moose;

with 'ModelSEED::Role::DBObject' => {
        rose_class => "ModelSEED::DB::Biochemistry",
        attribute_roles => {
            'uuid' => 'ModelSEED::Role::UUID',
            'modDate' => 'ModelSEED::Role::ModDate'
        },
    };

1;
