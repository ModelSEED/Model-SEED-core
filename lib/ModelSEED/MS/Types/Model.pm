#
# Subtypes for ModelSEED::MS::Model
#
package ModelSEED::MS::Types::Model;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Model;

coerce 'ModelSEED::MS::Model',
    from 'HashRef',
    via { ModelSEED::MS::DB::Model->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModel',
    as 'ArrayRef[ModelSEED::MS::Model]';
coerce 'ModelSEED::MS::ArrayRefOfModel',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Model->new( $_ ) } @{$_} ] };

1;
