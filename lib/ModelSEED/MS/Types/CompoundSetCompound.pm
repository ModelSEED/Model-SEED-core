#
# Subtypes for ModelSEED::MS::CompoundSetCompound
#
package ModelSEED::MS::Types::CompoundSetCompound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundSetCompound;

coerce 'ModelSEED::MS::CompoundSetCompound',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundSetCompound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundSetCompound',
    as 'ArrayRef[ModelSEED::MS::CompoundSetCompound]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundSetCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::CompoundSetCompound->new( $_ ) } @{$_} ] };

1;
