#
# Subtypes for ModelSEED::MS::Mapping
#
package ModelSEED::MS::Types::Mapping;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Mapping;

coerce 'ModelSEED::MS::Mapping',
    from 'HashRef',
    via { ModelSEED::MS::DB::Mapping->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfMapping',
    as 'ArrayRef[ModelSEED::MS::Mapping]';
coerce 'ModelSEED::MS::ArrayRefOfMapping',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Mapping->new( $_ ) } @{$_} ] };

1;
