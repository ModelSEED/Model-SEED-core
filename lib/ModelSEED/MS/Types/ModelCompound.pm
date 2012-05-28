#
# Subtypes for ModelSEED::MS::ModelCompound
#
package ModelSEED::MS::Types::ModelCompound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelCompound;

coerce 'ModelSEED::MS::ModelCompound',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelCompound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelCompound',
    as 'ArrayRef[ModelSEED::MS::ModelCompound]';
coerce 'ModelSEED::MS::ArrayRefOfModelCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelCompound->new( $_ ) } @{$_} ] };

1;
