#
# Subtypes for ModelSEED::MS::InstanceTransport
#
package ModelSEED::MS::Types::InstanceTransport;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::InstanceTransport;

coerce 'ModelSEED::MS::DB::InstanceTransport',
    from 'HashRef',
    via { ModelSEED::MS::DB::InstanceTransport->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfInstanceTransport',
    as 'ArrayRef[ModelSEED::MS::DB::InstanceTransport]';
coerce 'ModelSEED::MS::ArrayRefOfInstanceTransport',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::InstanceTransport->new( $_ ) } @{$_} ] };

1;
