#
# Subtypes for ModelSEED::MS::Deletion
#
package ModelSEED::MS::Types::Deletion;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Deletion;

coerce 'ModelSEED::MS::DB::Deletion',
    from 'HashRef',
    via { ModelSEED::MS::DB::Deletion->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfDeletion',
    as 'ArrayRef[ModelSEED::MS::DB::Deletion]';
coerce 'ModelSEED::MS::ArrayRefOfDeletion',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Deletion->new( $_ ) } @{$_} ] };

1;
