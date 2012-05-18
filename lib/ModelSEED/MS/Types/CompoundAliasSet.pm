#
# Subtypes for ModelSEED::MS::CompoundAliasSet
#
package ModelSEED::MS::Types::CompoundAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundAliasSet;

coerce 'ModelSEED::MS::CompoundAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundAliasSet',
    as 'ArrayRef[ModelSEED::MS::CompoundAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::CompoundAliasSet->new( $_ ) } @{$_} ] };

1;
