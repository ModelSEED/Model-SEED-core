#
# Subtypes for ModelSEED::MS::ModelReactionProtein
#
package ModelSEED::MS::Types::ModelReactionProtein;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionProtein;

coerce 'ModelSEED::MS::ModelReactionProtein',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelReactionProtein->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelReactionProtein',
    as 'ArrayRef[ModelSEED::MS::ModelReactionProtein]';
coerce 'ModelSEED::MS::ArrayRefOfModelReactionProtein',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelReactionProtein->new( $_ ) } @{$_} ] };

1;
