#
# Subtypes for ModelSEED::MS::ComplexAliasSet
#
package ModelSEED::MS::Types::ComplexAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ComplexAliasSet;

coerce 'ModelSEED::MS::DB::ComplexAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexAliasSet',
    as 'ArrayRef[ModelSEED::MS::DB::ComplexAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfComplexAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ComplexAliasSet->new( $_ ) } @{$_} ] };

1;
