#
# Subtypes for ModelSEED::MS::CompoundStructure
#
package ModelSEED::MS::Types::CompoundStructure;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::CompoundStructure );

coerce 'ModelSEED::MS::CompoundStructure',
    from 'HashRef',
    via { ModelSEED::MS::DB::CompoundStructure->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompoundStructure',
    as 'ArrayRef[ModelSEED::MS::DB::CompoundStructure]';
coerce 'ModelSEED::MS::ArrayRefOfCompoundStructure',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::CompoundStructure->new( $_ ) } @{$_} ] };

1;
