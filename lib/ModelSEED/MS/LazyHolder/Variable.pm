# Holder for ModelSEED::MS::Variable
package ModelSEED::MS::LazyHolder::Variable;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Variable;
use ModelSEED::MS::Types::Variable;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Variable::Lazy',
        as 'ModelSEED::MS::LazyHolder::Variable';
    coerce 'ModelSEED::MS::Variable::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Variable->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfVariable',
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

