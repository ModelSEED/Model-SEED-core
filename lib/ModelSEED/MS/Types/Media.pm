#
# Subtypes for ModelSEED::MS::Media
#
package ModelSEED::MS::Types::Media;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Media );

coerce 'ModelSEED::MS::Media',
    from 'HashRef',
    via { ModelSEED::MS::DB::Media->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfMedia',
    as 'ArrayRef[ModelSEED::MS::DB::Media]';
coerce 'ModelSEED::MS::ArrayRefOfMedia',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Media->new( $_ ) } @{$_} ] };

1;
