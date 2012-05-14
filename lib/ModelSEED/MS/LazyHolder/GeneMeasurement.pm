# Holder for ModelSEED::MS::GeneMeasurement
package ModelSEED::MS::LazyHolder::GeneMeasurement;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GeneMeasurement;
use ModelSEED::MS::Types::GeneMeasurement;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::GeneMeasurement::Lazy',
        as 'ModelSEED::MS::LazyHolder::GeneMeasurement';
    coerce 'ModelSEED::MS::GeneMeasurement::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::GeneMeasurement->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfGeneMeasurement',
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

