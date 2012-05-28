#
# Subtypes for ModelSEED::MS::ModelReactionReagent
#
package ModelSEED::MS::Types::ModelReactionReagent;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionReagent;

coerce 'ModelSEED::MS::ModelReactionReagent',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelReactionReagent->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelReactionReagent',
    as 'ArrayRef[ModelSEED::MS::ModelReactionReagent]';
coerce 'ModelSEED::MS::ArrayRefOfModelReactionReagent',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelReactionReagent->new( $_ ) } @{$_} ] };

1;
