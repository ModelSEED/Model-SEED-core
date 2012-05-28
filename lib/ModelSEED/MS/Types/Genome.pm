#
# Subtypes for ModelSEED::MS::Genome
#
package ModelSEED::MS::Types::Genome;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Genome;

coerce 'ModelSEED::MS::Genome',
    from 'HashRef',
    via { ModelSEED::MS::DB::Genome->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfGenome',
    as 'ArrayRef[ModelSEED::MS::Genome]';
coerce 'ModelSEED::MS::ArrayRefOfGenome',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Genome->new( $_ ) } @{$_} ] };

1;
