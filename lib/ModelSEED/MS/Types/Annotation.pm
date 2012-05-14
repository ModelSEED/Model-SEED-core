#
# Subtypes for ModelSEED::MS::Annotation
#
package ModelSEED::MS::Types::Annotation;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Annotation );

coerce 'ModelSEED::MS::Annotation',
    from 'HashRef',
    via { ModelSEED::MS::DB::Annotation->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfAnnotation',
    as 'ArrayRef[ModelSEED::MS::DB::Annotation]';
coerce 'ModelSEED::MS::ArrayRefOfAnnotation',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Annotation->new( $_ ) } @{$_} ] };

1;
