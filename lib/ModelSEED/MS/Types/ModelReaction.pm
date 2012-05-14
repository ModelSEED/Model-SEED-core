#
# Subtypes for ModelSEED::MS::ModelReaction
#
package ModelSEED::MS::Types::ModelReaction;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::ModelReaction );

coerce 'ModelSEED::MS::ModelReaction',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelReaction->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelReaction',
    as 'ArrayRef[ModelSEED::MS::DB::ModelReaction]';
coerce 'ModelSEED::MS::ArrayRefOfModelReaction',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ModelReaction->new( $_ ) } @{$_} ] };

1;
