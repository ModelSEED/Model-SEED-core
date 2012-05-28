#
# Subtypes for ModelSEED::MS::FBAResults
#
package ModelSEED::MS::Types::FBAResults;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAResults;

coerce 'ModelSEED::MS::FBAResults',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAResults->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAResults',
    as 'ArrayRef[ModelSEED::MS::FBAResults]';
coerce 'ModelSEED::MS::ArrayRefOfFBAResults',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAResults->new( $_ ) } @{$_} ] };

1;
