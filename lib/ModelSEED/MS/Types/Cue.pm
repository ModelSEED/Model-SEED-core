#
# Subtypes for ModelSEED::MS::Cue
#
package ModelSEED::MS::Types::Cue;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Cue );

coerce 'ModelSEED::MS::Cue',
    from 'HashRef',
    via { ModelSEED::MS::DB::Cue->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCue',
    as 'ArrayRef[ModelSEED::MS::DB::Cue]';
coerce 'ModelSEED::MS::ArrayRefOfCue',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Cue->new( $_ ) } @{$_} ] };

1;
