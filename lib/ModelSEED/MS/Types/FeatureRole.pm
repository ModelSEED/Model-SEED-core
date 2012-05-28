#
# Subtypes for ModelSEED::MS::FeatureRole
#
package ModelSEED::MS::Types::FeatureRole;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FeatureRole;

coerce 'ModelSEED::MS::FeatureRole',
    from 'HashRef',
    via { ModelSEED::MS::DB::FeatureRole->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFeatureRole',
    as 'ArrayRef[ModelSEED::MS::FeatureRole]';
coerce 'ModelSEED::MS::ArrayRefOfFeatureRole',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FeatureRole->new( $_ ) } @{$_} ] };

1;
