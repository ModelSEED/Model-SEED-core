#
# Subtypes for ModelSEED::MS::Insertion
#
package ModelSEED::MS::Types::Insertion;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Insertion;

coerce 'ModelSEED::MS::Insertion',
    from 'HashRef',
    via { ModelSEED::MS::DB::Insertion->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfInsertion',
    as 'ArrayRef[ModelSEED::MS::Insertion]';
coerce 'ModelSEED::MS::ArrayRefOfInsertion',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Insertion->new( $_ ) } @{$_} ] };

1;
