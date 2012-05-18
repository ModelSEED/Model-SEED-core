#
# Subtypes for ModelSEED::MS::FBASolution
#
package ModelSEED::MS::Types::FBASolution;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBASolution;

coerce 'ModelSEED::MS::FBASolution',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBASolution->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBASolution',
    as 'ArrayRef[ModelSEED::MS::FBASolution]';
coerce 'ModelSEED::MS::ArrayRefOfFBASolution',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBASolution->new( $_ ) } @{$_} ] };

1;
