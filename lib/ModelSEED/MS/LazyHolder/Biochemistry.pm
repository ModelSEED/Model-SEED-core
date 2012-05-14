# Holder for ModelSEED::MS::Biochemistry
package ModelSEED::MS::LazyHolder::Biochemistry;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Types::Biochemistry;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Biochemistry::Lazy',
        as 'ModelSEED::MS::LazyHolder::Biochemistry';
    coerce 'ModelSEED::MS::Biochemistry::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Biochemistry->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfBiochemistry',
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

