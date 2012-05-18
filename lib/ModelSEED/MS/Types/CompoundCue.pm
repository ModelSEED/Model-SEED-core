#
# Subtypes for ModelSEED::MS::CompoundCue
#
package ModelSEED::MS::Types::CompoundCue;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundCue;

coerce 'ModelSEED::MS::CompoundCue',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundCue->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundCue',
    as 'ArrayRef[ModelSEED::MS::CompoundCue]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundCue',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::CompoundCue->new( $_ ) } @{$_} ] };

1;
