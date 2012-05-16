#
# Subtypes for ModelSEED::MS::FBAProblem
#
package ModelSEED::MS::Types::FBAProblem;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::FBAProblem;

coerce 'ModelSEED::MS::DB::FBAProblem',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAProblem->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAProblem',
    as 'ArrayRef[ModelSEED::MS::DB::FBAProblem]';
coerce 'ModelSEED::MS::ArrayRefOfFBAProblem',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::FBAProblem->new( $_ ) } @{$_} ] };

1;
