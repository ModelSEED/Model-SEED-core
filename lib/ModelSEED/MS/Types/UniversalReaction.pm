#
# Subtypes for ModelSEED::MS::UniversalReaction
#
package ModelSEED::MS::Types::UniversalReaction;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::UniversalReaction );

coerce 'ModelSEED::MS::UniversalReaction',
    from 'HashRef',
    via { ModelSEED::MS::DB::UniversalReaction->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfUniversalReaction',
    as 'ArrayRef[ModelSEED::MS::DB::UniversalReaction]';
coerce 'ModelSEED::MS::ArrayRefOfUniversalReaction',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::UniversalReaction->new( $_ ) } @{$_} ] };

1;
