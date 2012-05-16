# Holder for ModelSEED::MS::MetaboliteMeasurement
package ModelSEED::MS::LazyHolder::MetaboliteMeasurement;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::MetaboliteMeasurement;
use ModelSEED::MS::Types::MetaboliteMeasurement;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::MetaboliteMeasurement::Lazy',
        as 'ModelSEED::MS::LazyHolder::MetaboliteMeasurement';
    coerce 'ModelSEED::MS::MetaboliteMeasurement::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::MetaboliteMeasurement->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfMetaboliteMeasurement',
    lazy    => 1,
    coerce  => 1,
    builder => '_build'
);

sub _build {
    my ($self) = @_; 
    my $val = $self->uncoerced;
    $self->uncoerced(undef);
    return $val;
}
__PACKAGE__->meta->make_immutable;
1;

