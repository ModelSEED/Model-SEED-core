#
# Subtypes for ModelSEED::MS::GapfillingSolution
#
package ModelSEED::MS::Types::GapfillingSolution;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingSolution;

coerce 'ModelSEED::MS::GapfillingSolution',
    from 'HashRef',
    via { ModelSEED::MS::DB::GapfillingSolution->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfGapfillingSolution',
    as 'ArrayRef[ModelSEED::MS::GapfillingSolution]';
coerce 'ModelSEED::MS::ArrayRefOfGapfillingSolution',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::GapfillingSolution->new( $_ ) } @{$_} ] };

1;
