#
# Subtypes for ModelSEED::MS::CompoundSet
#
package ModelSEED::MS::Types::CompoundSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::CompoundSet;

coerce 'ModelSEED::MS::DB::CompoundSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundSet',
    as 'ArrayRef[ModelSEED::MS::DB::CompoundSet]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::CompoundSet->new( $_ ) } @{$_} ] };

1;
