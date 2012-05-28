#
# Subtypes for ModelSEED::MS::ModelReactionProteinSubunitGene
#
package ModelSEED::MS::Types::ModelReactionProteinSubunitGene;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionProteinSubunitGene;

coerce 'ModelSEED::MS::ModelReactionProteinSubunitGene',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelReactionProteinSubunitGene->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelReactionProteinSubunitGene',
    as 'ArrayRef[ModelSEED::MS::ModelReactionProteinSubunitGene]';
coerce 'ModelSEED::MS::ArrayRefOfModelReactionProteinSubunitGene',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelReactionProteinSubunitGene->new( $_ ) } @{$_} ] };

1;
