#
# Subtypes for ModelSEED::MS::CompoundPk
#
package ModelSEED::MS::Types::CompoundPk;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::CompoundPk;

coerce 'ModelSEED::MS::DB::CompoundPk',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundPk->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundPk',
    as 'ArrayRef[ModelSEED::MS::DB::CompoundPk]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundPk',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::CompoundPk->new( $_ ) } @{$_} ] };

1;
