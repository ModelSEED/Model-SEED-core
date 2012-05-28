#
# Subtypes for ModelSEED::MS::ModelReactionProteinSubunit
#
package ModelSEED::MS::Types::ModelReactionProteinSubunit;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionProteinSubunit;

coerce 'ModelSEED::MS::ModelReactionProteinSubunit',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelReactionProteinSubunit->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelReactionProteinSubunit',
    as 'ArrayRef[ModelSEED::MS::ModelReactionProteinSubunit]';
coerce 'ModelSEED::MS::ArrayRefOfModelReactionProteinSubunit',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelReactionProteinSubunit->new( $_ ) } @{$_} ] };

1;
