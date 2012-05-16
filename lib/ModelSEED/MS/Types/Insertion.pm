#
# Subtypes for ModelSEED::MS::Insertion
#
package ModelSEED::MS::Types::Insertion;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Insertion;

coerce 'ModelSEED::MS::DB::Insertion',
    from 'HashRef',
    via { ModelSEED::MS::DB::Insertion->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfInsertion',
    as 'ArrayRef[ModelSEED::MS::DB::Insertion]';
coerce 'ModelSEED::MS::ArrayRefOfInsertion',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Insertion->new( $_ ) } @{$_} ] };

1;