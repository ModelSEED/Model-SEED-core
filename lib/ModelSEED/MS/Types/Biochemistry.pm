#
# Subtypes for ModelSEED::MS::Biochemistry
#
package ModelSEED::MS::Types::Biochemistry;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Biochemistry;

coerce 'ModelSEED::MS::Biochemistry',
    from 'HashRef',
    via { ModelSEED::MS::DB::Biochemistry->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiochemistry',
    as 'ArrayRef[ModelSEED::MS::Biochemistry]';
coerce 'ModelSEED::MS::ArrayRefOfBiochemistry',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Biochemistry->new( $_ ) } @{$_} ] };

1;
