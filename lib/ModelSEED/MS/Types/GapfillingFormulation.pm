#
# Subtypes for ModelSEED::MS::GapfillingFormulation
#
package ModelSEED::MS::Types::GapfillingFormulation;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingFormulation;

coerce 'ModelSEED::MS::GapfillingFormulation',
    from 'HashRef',
    via { ModelSEED::MS::DB::GapfillingFormulation->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfGapfillingFormulation',
    as 'ArrayRef[ModelSEED::MS::GapfillingFormulation]';
coerce 'ModelSEED::MS::ArrayRefOfGapfillingFormulation',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::GapfillingFormulation->new( $_ ) } @{$_} ] };

1;
