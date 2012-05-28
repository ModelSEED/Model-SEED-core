#
# Subtypes for ModelSEED::MS::ModelAnalysis
#
package ModelSEED::MS::Types::ModelAnalysis;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysis;

coerce 'ModelSEED::MS::ModelAnalysis',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelAnalysis->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelAnalysis',
    as 'ArrayRef[ModelSEED::MS::ModelAnalysis]';
coerce 'ModelSEED::MS::ArrayRefOfModelAnalysis',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelAnalysis->new( $_ ) } @{$_} ] };

1;
