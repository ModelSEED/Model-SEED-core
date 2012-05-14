# Holder for ModelSEED::MS::Genome
package ModelSEED::MS::LazyHolder::Genome;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Genome;
use ModelSEED::MS::Types::Genome;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Genome::Lazy',
        as 'ModelSEED::MS::LazyHolder::Genome';
    coerce 'ModelSEED::MS::Genome::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Genome->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfGenome',
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

