#
# Subtypes for ModelSEED::MS::CompoundAliasSet
#
package ModelSEED::MS::Types::CompoundAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::CompoundAliasSet;

coerce 'ModelSEED::MS::DB::CompoundAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundAliasSet',
    as 'ArrayRef[ModelSEED::MS::DB::CompoundAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::CompoundAliasSet->new( $_ ) } @{$_} ] };

1;
