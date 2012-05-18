#
# Subtypes for ModelSEED::MS::MediaCompound
#
package ModelSEED::MS::Types::MediaCompound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::MediaCompound;

coerce 'ModelSEED::MS::MediaCompound',
    from 'HashRef',
    via { ModelSEED::MS::DB::MediaCompound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfMediaCompound',
    as 'ArrayRef[ModelSEED::MS::MediaCompound]';
coerce 'ModelSEED::MS::ArrayRefOfMediaCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::MediaCompound->new( $_ ) } @{$_} ] };

1;
