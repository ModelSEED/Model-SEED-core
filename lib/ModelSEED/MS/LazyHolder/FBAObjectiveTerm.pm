# Holder for ModelSEED::MS::FBAObjectiveTerm
package ModelSEED::MS::LazyHolder::FBAObjectiveTerm;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAObjectiveTerm;
use ModelSEED::MS::Types::FBAObjectiveTerm;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAObjectiveTerm::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAObjectiveTerm';
    coerce 'ModelSEED::MS::FBAObjectiveTerm::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAObjectiveTerm->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAObjectiveTerm',
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

