# Holder for ModelSEED::MS::Solution
package ModelSEED::MS::LazyHolder::Solution;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Solution;
use ModelSEED::MS::Types::Solution;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Solution::Lazy',
        as 'ModelSEED::MS::LazyHolder::Solution';
    coerce 'ModelSEED::MS::Solution::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Solution->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfSolution',
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

