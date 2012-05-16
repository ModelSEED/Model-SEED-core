#
# Subtypes for ModelSEED::MS::Cue
#
package ModelSEED::MS::Types::Cue;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Cue;

coerce 'ModelSEED::MS::DB::Cue',
    from 'HashRef',
    via { ModelSEED::MS::DB::Cue->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCue',
    as 'ArrayRef[ModelSEED::MS::DB::Cue]';
coerce 'ModelSEED::MS::ArrayRefOfCue',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Cue->new( $_ ) } @{$_} ] };

1;
