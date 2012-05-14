# Holder for ModelSEED::MS::CompoundCue
package ModelSEED::MS::LazyHolder::CompoundCue;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundCue;
use ModelSEED::MS::Types::CompoundCue;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::CompoundCue::Lazy',
        as 'ModelSEED::MS::LazyHolder::CompoundCue';
    coerce 'ModelSEED::MS::CompoundCue::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::CompoundCue->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompoundCue',
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

