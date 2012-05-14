#
# Subtypes for ModelSEED::MS::FBAObjectiveTerm
#
package ModelSEED::MS::Types::FBAObjectiveTerm;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::FBAObjectiveTerm );

coerce 'ModelSEED::MS::FBAObjectiveTerm',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAObjectiveTerm->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAObjectiveTerm',
    as 'ArrayRef[ModelSEED::MS::DB::FBAObjectiveTerm]';
coerce 'ModelSEED::MS::ArrayRefOfFBAObjectiveTerm',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::FBAObjectiveTerm->new( $_ ) } @{$_} ] };

1;
