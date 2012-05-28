# Holder for ModelSEED::MS::UptakeMeasurement
package ModelSEED::MS::LazyHolder::UptakeMeasurement;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::UptakeMeasurement;
use ModelSEED::MS::Types::UptakeMeasurement;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::UptakeMeasurement::Lazy',
        as 'ModelSEED::MS::LazyHolder::UptakeMeasurement';
    coerce 'ModelSEED::MS::UptakeMeasurement::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::UptakeMeasurement->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfUptakeMeasurement',
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

