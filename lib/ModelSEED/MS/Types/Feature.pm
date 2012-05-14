#
# Subtypes for ModelSEED::MS::Feature
#
package ModelSEED::MS::Types::Feature;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Feature;

coerce 'ModelSEED::MS::DB::Feature',
    from 'HashRef',
    via { ModelSEED::MS::DB::Feature->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFeature',
    as 'ArrayRef[ModelSEED::MS::DB::Feature]';
coerce 'ModelSEED::MS::ArrayRefOfFeature',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Feature->new( $_ ) } @{$_} ] };

1;
