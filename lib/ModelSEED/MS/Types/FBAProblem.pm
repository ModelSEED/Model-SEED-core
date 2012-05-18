#
# Subtypes for ModelSEED::MS::FBAProblem
#
package ModelSEED::MS::Types::FBAProblem;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAProblem;

coerce 'ModelSEED::MS::FBAProblem',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAProblem->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAProblem',
    as 'ArrayRef[ModelSEED::MS::FBAProblem]';
coerce 'ModelSEED::MS::ArrayRefOfFBAProblem',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAProblem->new( $_ ) } @{$_} ] };

1;
