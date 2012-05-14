# Holder for ModelSEED::MS::MediaCompound
package ModelSEED::MS::LazyHolder::MediaCompound;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::MediaCompound;
use ModelSEED::MS::Types::MediaCompound;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::MediaCompound::Lazy',
        as 'ModelSEED::MS::LazyHolder::MediaCompound';
    coerce 'ModelSEED::MS::MediaCompound::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::MediaCompound->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfMediaCompound',
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

