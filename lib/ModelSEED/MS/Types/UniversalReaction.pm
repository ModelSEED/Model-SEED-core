#
# Subtypes for ModelSEED::MS::UniversalReaction
#
package ModelSEED::MS::Types::UniversalReaction;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::UniversalReaction;

coerce 'ModelSEED::MS::UniversalReaction',
    from 'HashRef',
    via { ModelSEED::MS::DB::UniversalReaction->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfUniversalReaction',
    as 'ArrayRef[ModelSEED::MS::UniversalReaction]';
coerce 'ModelSEED::MS::ArrayRefOfUniversalReaction',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::UniversalReaction->new( $_ ) } @{$_} ] };

1;
