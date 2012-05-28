#
# Subtypes for ModelSEED::MS::CompoundPk
#
package ModelSEED::MS::Types::CompoundPk;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundPk;

coerce 'ModelSEED::MS::CompoundPk',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundPk->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundPk',
    as 'ArrayRef[ModelSEED::MS::CompoundPk]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundPk',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::CompoundPk->new( $_ ) } @{$_} ] };

1;
