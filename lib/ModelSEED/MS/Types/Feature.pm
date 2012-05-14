#
# Subtypes for ModelSEED::MS::Feature
#
package ModelSEED::MS::Types::Feature;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Feature );

coerce 'ModelSEED::MS::Feature',
    from 'HashRef',
    via { ModelSEED::MS::DB::Feature->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFeature',
    as 'ArrayRef[ModelSEED::MS::DB::Feature]';
coerce 'ModelSEED::MS::ArrayRefOfFeature',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Feature->new( $_ ) } @{$_} ] };

1;
