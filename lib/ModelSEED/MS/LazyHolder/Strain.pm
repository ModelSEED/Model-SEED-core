# Holder for ModelSEED::MS::Strain
package ModelSEED::MS::LazyHolder::Strain;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Strain;
use ModelSEED::MS::Types::Strain;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Strain::Lazy',
        as 'ModelSEED::MS::LazyHolder::Strain';
    coerce 'ModelSEED::MS::Strain::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Strain->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfStrain',
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

