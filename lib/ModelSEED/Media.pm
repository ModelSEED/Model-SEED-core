package ModelSEED::Media;
use Moose;
use ModelSEED::Role::DBObject;


with 'ModelSEED::Role::DBObject' => { 
        rose_class => "ModelSEED::DB::Media",
        attribute_roles => {
            'uuid' => 'ModelSEED::Role::UUID',
            'modDate' => 'ModelSEED::Role::ModDate'
        },
    };
1;
