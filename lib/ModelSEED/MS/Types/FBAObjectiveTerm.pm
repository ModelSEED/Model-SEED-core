#
# Subtypes for ModelSEED::MS::FBAObjectiveTerm
#
package ModelSEED::MS::Types::FBAObjectiveTerm;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::FBAObjectiveTerm;

coerce 'ModelSEED::MS::DB::FBAObjectiveTerm',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAObjectiveTerm->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAObjectiveTerm',
    as 'ArrayRef[ModelSEED::MS::DB::FBAObjectiveTerm]';
coerce 'ModelSEED::MS::ArrayRefOfFBAObjectiveTerm',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::FBAObjectiveTerm->new( $_ ) } @{$_} ] };

1;
