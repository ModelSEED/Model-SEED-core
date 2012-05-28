#
# Subtypes for ModelSEED::MS::GapfillingGeneCandidate
#
package ModelSEED::MS::Types::GapfillingGeneCandidate;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingGeneCandidate;

coerce 'ModelSEED::MS::GapfillingGeneCandidate',
    from 'HashRef',
    via { ModelSEED::MS::DB::GapfillingGeneCandidate->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfGapfillingGeneCandidate',
    as 'ArrayRef[ModelSEED::MS::GapfillingGeneCandidate]';
coerce 'ModelSEED::MS::ArrayRefOfGapfillingGeneCandidate',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::GapfillingGeneCandidate->new( $_ ) } @{$_} ] };

1;
