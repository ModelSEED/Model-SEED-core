#
# Subtypes for ModelSEED::MS::FBACompoundVariable
#
package ModelSEED::MS::Types::FBACompoundVariable;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::FBACompoundVariable );

coerce 'ModelSEED::MS::FBACompoundVariable',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBACompoundVariable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBACompoundVariable',
    as 'ArrayRef[ModelSEED::MS::DB::FBACompoundVariable]';
coerce 'ModelSEED::MS::ArrayRefOfFBACompoundVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::FBACompoundVariable->new( $_ ) } @{$_} ] };

1;
