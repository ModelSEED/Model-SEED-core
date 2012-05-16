#
# Subtypes for ModelSEED::MS::Mapping
#
package ModelSEED::MS::Types::Mapping;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Mapping;

coerce 'ModelSEED::MS::DB::Mapping',
    from 'HashRef',
    via { ModelSEED::MS::DB::Mapping->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfMapping',
    as 'ArrayRef[ModelSEED::MS::DB::Mapping]';
coerce 'ModelSEED::MS::ArrayRefOfMapping',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Mapping->new( $_ ) } @{$_} ] };

1;
