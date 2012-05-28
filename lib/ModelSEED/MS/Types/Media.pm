#
# Subtypes for ModelSEED::MS::Media
#
package ModelSEED::MS::Types::Media;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Media;

coerce 'ModelSEED::MS::Media',
    from 'HashRef',
    via { ModelSEED::MS::DB::Media->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfMedia',
    as 'ArrayRef[ModelSEED::MS::Media]';
coerce 'ModelSEED::MS::ArrayRefOfMedia',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Media->new( $_ ) } @{$_} ] };

1;
