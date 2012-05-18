#
# Subtypes for ModelSEED::MS::Compound
#
package ModelSEED::MS::Types::Compound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Compound;

coerce 'ModelSEED::MS::Compound',
    from 'HashRef',
    via { ModelSEED::MS::DB::Compound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompound',
    as 'ArrayRef[ModelSEED::MS::Compound]';
coerce 'ModelSEED::MS::ArrayRefOfCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Compound->new( $_ ) } @{$_} ] };

1;
