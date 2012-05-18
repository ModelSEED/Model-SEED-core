#
# Subtypes for ModelSEED::MS::Annotation
#
package ModelSEED::MS::Types::Annotation;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Annotation;

coerce 'ModelSEED::MS::Annotation',
    from 'HashRef',
    via { ModelSEED::MS::DB::Annotation->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfAnnotation',
    as 'ArrayRef[ModelSEED::MS::Annotation]';
coerce 'ModelSEED::MS::ArrayRefOfAnnotation',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Annotation->new( $_ ) } @{$_} ] };

1;
