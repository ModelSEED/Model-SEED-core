#
# Subtypes for ModelSEED::MS::Cue
#
package ModelSEED::MS::Types::Cue;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Cue;

coerce 'ModelSEED::MS::Cue',
    from 'HashRef',
    via { ModelSEED::MS::DB::Cue->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCue',
    as 'ArrayRef[ModelSEED::MS::Cue]';
coerce 'ModelSEED::MS::ArrayRefOfCue',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Cue->new( $_ ) } @{$_} ] };

1;
