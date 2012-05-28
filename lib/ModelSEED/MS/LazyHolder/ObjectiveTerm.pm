# Holder for ModelSEED::MS::ObjectiveTerm
package ModelSEED::MS::LazyHolder::ObjectiveTerm;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ObjectiveTerm;
use ModelSEED::MS::Types::ObjectiveTerm;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ObjectiveTerm::Lazy',
        as 'ModelSEED::MS::LazyHolder::ObjectiveTerm';
    coerce 'ModelSEED::MS::ObjectiveTerm::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ObjectiveTerm->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfObjectiveTerm',
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

