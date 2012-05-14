#
# Subtypes for ModelSEED::MS::Compound
#
package ModelSEED::MS::Types::Compound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Compound;

coerce 'ModelSEED::MS::DB::Compound',
    from 'HashRef',
    via { ModelSEED::MS::DB::Compound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompound',
    as 'ArrayRef[ModelSEED::MS::DB::Compound]';
coerce 'ModelSEED::MS::ArrayRefOfCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Compound->new( $_ ) } @{$_} ] };

1;
