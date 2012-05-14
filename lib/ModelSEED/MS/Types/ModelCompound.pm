#
# Subtypes for ModelSEED::MS::ModelCompound
#
package ModelSEED::MS::Types::ModelCompound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ModelCompound;

coerce 'ModelSEED::MS::DB::ModelCompound',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelCompound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelCompound',
    as 'ArrayRef[ModelSEED::MS::DB::ModelCompound]';
coerce 'ModelSEED::MS::ArrayRefOfModelCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ModelCompound->new( $_ ) } @{$_} ] };

1;
