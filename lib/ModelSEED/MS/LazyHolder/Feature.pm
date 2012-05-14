# Holder for ModelSEED::MS::Feature
package ModelSEED::MS::LazyHolder::Feature;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Feature;
use ModelSEED::MS::Types::Feature;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Feature::Lazy',
        as 'ModelSEED::MS::LazyHolder::Feature';
    coerce 'ModelSEED::MS::Feature::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Feature->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFeature',
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

