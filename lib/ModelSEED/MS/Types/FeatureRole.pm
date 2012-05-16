#
# Subtypes for ModelSEED::MS::FeatureRole
#
package ModelSEED::MS::Types::FeatureRole;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::FeatureRole;

coerce 'ModelSEED::MS::DB::FeatureRole',
    from 'HashRef',
    via { ModelSEED::MS::DB::FeatureRole->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFeatureRole',
    as 'ArrayRef[ModelSEED::MS::DB::FeatureRole]';
coerce 'ModelSEED::MS::ArrayRefOfFeatureRole',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::FeatureRole->new( $_ ) } @{$_} ] };

1;
