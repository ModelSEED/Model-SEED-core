#
# Subtypes for ModelSEED::MS::ObjectiveTerm
#
package ModelSEED::MS::Types::ObjectiveTerm;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ObjectiveTerm;

coerce 'ModelSEED::MS::DB::ObjectiveTerm',
    from 'HashRef',
    via { ModelSEED::MS::DB::ObjectiveTerm->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfObjectiveTerm',
    as 'ArrayRef[ModelSEED::MS::DB::ObjectiveTerm]';
coerce 'ModelSEED::MS::ArrayRefOfObjectiveTerm',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ObjectiveTerm->new( $_ ) } @{$_} ] };

1;
