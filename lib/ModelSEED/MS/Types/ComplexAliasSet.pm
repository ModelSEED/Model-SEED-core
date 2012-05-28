#
# Subtypes for ModelSEED::MS::ComplexAliasSet
#
package ModelSEED::MS::Types::ComplexAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexAliasSet;

coerce 'ModelSEED::MS::ComplexAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexAliasSet',
    as 'ArrayRef[ModelSEED::MS::ComplexAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfComplexAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ComplexAliasSet->new( $_ ) } @{$_} ] };

1;
