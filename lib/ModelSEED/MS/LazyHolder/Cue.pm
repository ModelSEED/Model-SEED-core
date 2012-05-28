# Holder for ModelSEED::MS::Cue
package ModelSEED::MS::LazyHolder::Cue;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Cue;
use ModelSEED::MS::Types::Cue;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Cue::Lazy',
        as 'ModelSEED::MS::LazyHolder::Cue';
    coerce 'ModelSEED::MS::Cue::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Cue->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCue',
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

