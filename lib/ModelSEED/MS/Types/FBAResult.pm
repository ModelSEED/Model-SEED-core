#
# Subtypes for ModelSEED::MS::FBAResult
#
package ModelSEED::MS::Types::FBAResult;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAResult;

coerce 'ModelSEED::MS::FBAResult',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAResult->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAResult',
    as 'ArrayRef[ModelSEED::MS::FBAResult]';
coerce 'ModelSEED::MS::ArrayRefOfFBAResult',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAResult->new( $_ ) } @{$_} ] };

1;
