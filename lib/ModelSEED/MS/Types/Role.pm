#
# Subtypes for ModelSEED::MS::Role
#
package ModelSEED::MS::Types::Role;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Role );

coerce 'ModelSEED::MS::Role',
    from 'HashRef',
    via { ModelSEED::MS::DB::Role->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRole',
    as 'ArrayRef[ModelSEED::MS::DB::Role]';
coerce 'ModelSEED::MS::ArrayRefOfRole',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Role->new( $_ ) } @{$_} ] };

1;
