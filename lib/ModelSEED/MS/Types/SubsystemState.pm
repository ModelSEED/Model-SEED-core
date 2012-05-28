#
# Subtypes for ModelSEED::MS::SubsystemState
#
package ModelSEED::MS::Types::SubsystemState;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::SubsystemState;

coerce 'ModelSEED::MS::SubsystemState',
    from 'HashRef',
    via { ModelSEED::MS::DB::SubsystemState->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfSubsystemState',
    as 'ArrayRef[ModelSEED::MS::SubsystemState]';
coerce 'ModelSEED::MS::ArrayRefOfSubsystemState',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::SubsystemState->new( $_ ) } @{$_} ] };

1;
