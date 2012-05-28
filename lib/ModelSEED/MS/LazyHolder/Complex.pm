# Holder for ModelSEED::MS::Complex
package ModelSEED::MS::LazyHolder::Complex;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Complex;
use ModelSEED::MS::Types::Complex;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Complex::Lazy',
        as 'ModelSEED::MS::LazyHolder::Complex';
    coerce 'ModelSEED::MS::Complex::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Complex->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfComplex',
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

