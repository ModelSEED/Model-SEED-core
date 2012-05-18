#
# Subtypes for ModelSEED::MS::InstanceTransport
#
package ModelSEED::MS::Types::InstanceTransport;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::InstanceTransport;

coerce 'ModelSEED::MS::InstanceTransport',
    from 'HashRef',
    via { ModelSEED::MS::DB::InstanceTransport->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfInstanceTransport',
    as 'ArrayRef[ModelSEED::MS::InstanceTransport]';
coerce 'ModelSEED::MS::ArrayRefOfInstanceTransport',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::InstanceTransport->new( $_ ) } @{$_} ] };

1;
