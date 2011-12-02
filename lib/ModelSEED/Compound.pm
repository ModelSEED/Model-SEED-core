package ModelSEED::Compound;
use Moose;
use ModelSEED::Role::DBObject;
use namespace::autoclean;

with 'ModelSEED::Role::DBObject' => {
        rose_class => "ModelSEED::DB::Compound",
        attribute_roles => {
            'uuid' => 'ModelSEED::Role::UUID',
            'modDate' => 'ModelSEED::Role::ModDate'
        },
    };

__PACKAGE__->meta->make_immutable;
1;
