#
# Subtypes for ModelSEED::MS::CompoundAlias
#
package ModelSEED::MS::Types::CompoundAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundAlias;

coerce 'ModelSEED::MS::CompoundAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundAlias',
    as 'ArrayRef[ModelSEED::MS::CompoundAlias]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::CompoundAlias->new( $_ ) } @{$_} ] };

1;
