#
# Subtypes for ModelSEED::MS::Feature
#
package ModelSEED::MS::Types::Feature;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Feature;

coerce 'ModelSEED::MS::Feature',
    from 'HashRef',
    via { ModelSEED::MS::DB::Feature->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFeature',
    as 'ArrayRef[ModelSEED::MS::Feature]';
coerce 'ModelSEED::MS::ArrayRefOfFeature',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Feature->new( $_ ) } @{$_} ] };

1;
