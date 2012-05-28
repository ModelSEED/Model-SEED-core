#
# Subtypes for ModelSEED::MS::CompoundStructure
#
package ModelSEED::MS::Types::CompoundStructure;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundStructure;

coerce 'ModelSEED::MS::CompoundStructure',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundStructure->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundStructure',
    as 'ArrayRef[ModelSEED::MS::CompoundStructure]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundStructure',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::CompoundStructure->new( $_ ) } @{$_} ] };

1;
