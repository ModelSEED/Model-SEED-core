#
# Subtypes for ModelSEED::MS::CompoundStructure
#
package ModelSEED::MS::Types::CompoundStructure;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::CompoundStructure;

coerce 'ModelSEED::MS::DB::CompoundStructure',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundStructure->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundStructure',
    as 'ArrayRef[ModelSEED::MS::DB::CompoundStructure]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundStructure',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::CompoundStructure->new( $_ ) } @{$_} ] };

1;
