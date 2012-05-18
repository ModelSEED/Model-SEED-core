#
# Subtypes for ModelSEED::MS::FBAReactionVariable
#
package ModelSEED::MS::Types::FBAReactionVariable;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAReactionVariable;

coerce 'ModelSEED::MS::FBAReactionVariable',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAReactionVariable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAReactionVariable',
    as 'ArrayRef[ModelSEED::MS::FBAReactionVariable]';
coerce 'ModelSEED::MS::ArrayRefOfFBAReactionVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAReactionVariable->new( $_ ) } @{$_} ] };

1;
