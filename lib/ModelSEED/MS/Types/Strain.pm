#
# Subtypes for ModelSEED::MS::Strain
#
package ModelSEED::MS::Types::Strain;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Strain;

coerce 'ModelSEED::MS::DB::Strain',
    from 'HashRef',
    via { ModelSEED::MS::DB::Strain->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfStrain',
    as 'ArrayRef[ModelSEED::MS::DB::Strain]';
coerce 'ModelSEED::MS::ArrayRefOfStrain',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Strain->new( $_ ) } @{$_} ] };

1;
