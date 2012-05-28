#
# Subtypes for ModelSEED::MS::Deletion
#
package ModelSEED::MS::Types::Deletion;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Deletion;

coerce 'ModelSEED::MS::Deletion',
    from 'HashRef',
    via { ModelSEED::MS::DB::Deletion->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfDeletion',
    as 'ArrayRef[ModelSEED::MS::Deletion]';
coerce 'ModelSEED::MS::ArrayRefOfDeletion',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Deletion->new( $_ ) } @{$_} ] };

1;
