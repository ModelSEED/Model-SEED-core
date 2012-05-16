#
# Subtypes for ModelSEED::MS::Variable
#
package ModelSEED::MS::Types::Variable;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Variable;

coerce 'ModelSEED::MS::DB::Variable',
    from 'HashRef',
    via { ModelSEED::MS::DB::Variable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfVariable',
    as 'ArrayRef[ModelSEED::MS::DB::Variable]';
coerce 'ModelSEED::MS::ArrayRefOfVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Variable->new( $_ ) } @{$_} ] };

1;
