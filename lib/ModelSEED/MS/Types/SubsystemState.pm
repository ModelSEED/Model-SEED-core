#
# Subtypes for ModelSEED::MS::SubsystemState
#
package ModelSEED::MS::Types::SubsystemState;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::SubsystemState );

coerce 'ModelSEED::MS::SubsystemState',
    from 'HashRef',
    via { ModelSEED::MS::DB::SubsystemState->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfSubsystemState',
    as 'ArrayRef[ModelSEED::MS::DB::SubsystemState]';
coerce 'ModelSEED::MS::ArrayRefOfSubsystemState',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::SubsystemState->new( $_ ) } @{$_} ] };

1;
