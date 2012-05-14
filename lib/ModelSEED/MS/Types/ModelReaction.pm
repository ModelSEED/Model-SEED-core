#
# Subtypes for ModelSEED::MS::ModelReaction
#
package ModelSEED::MS::Types::ModelReaction;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ModelReaction;

coerce 'ModelSEED::MS::DB::ModelReaction',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelReaction->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelReaction',
    as 'ArrayRef[ModelSEED::MS::DB::ModelReaction]';
coerce 'ModelSEED::MS::ArrayRefOfModelReaction',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ModelReaction->new( $_ ) } @{$_} ] };

1;
