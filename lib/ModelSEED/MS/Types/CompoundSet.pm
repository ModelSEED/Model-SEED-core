#
# Subtypes for ModelSEED::MS::CompoundSet
#
package ModelSEED::MS::Types::CompoundSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundSet;

coerce 'ModelSEED::MS::CompoundSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundSet',
    as 'ArrayRef[ModelSEED::MS::CompoundSet]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::CompoundSet->new( $_ ) } @{$_} ] };

1;
