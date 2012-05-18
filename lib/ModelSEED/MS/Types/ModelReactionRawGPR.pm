#
# Subtypes for ModelSEED::MS::ModelReactionRawGPR
#
package ModelSEED::MS::Types::ModelReactionRawGPR;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionRawGPR;

coerce 'ModelSEED::MS::ModelReactionRawGPR',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelReactionRawGPR->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelReactionRawGPR',
    as 'ArrayRef[ModelSEED::MS::ModelReactionRawGPR]';
coerce 'ModelSEED::MS::ArrayRefOfModelReactionRawGPR',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelReactionRawGPR->new( $_ ) } @{$_} ] };

1;
