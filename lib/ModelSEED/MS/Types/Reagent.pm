#
# Subtypes for ModelSEED::MS::Reagent
#
package ModelSEED::MS::Types::Reagent;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Reagent;

coerce 'ModelSEED::MS::Reagent',
    from 'HashRef',
    via { ModelSEED::MS::DB::Reagent->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReagent',
    as 'ArrayRef[ModelSEED::MS::Reagent]';
coerce 'ModelSEED::MS::ArrayRefOfReagent',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Reagent->new( $_ ) } @{$_} ] };

1;
