#
# Subtypes for ModelSEED::MS::Biochemistry
#
package ModelSEED::MS::Types::Biochemistry;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Biochemistry );

coerce 'ModelSEED::MS::Biochemistry',
    from 'HashRef',
    via { ModelSEED::MS::DB::Biochemistry->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiochemistry',
    as 'ArrayRef[ModelSEED::MS::DB::Biochemistry]';
coerce 'ModelSEED::MS::ArrayRefOfBiochemistry',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Biochemistry->new( $_ ) } @{$_} ] };

1;
