# Holder for ModelSEED::MS::ModelAnalysis
package ModelSEED::MS::LazyHolder::ModelAnalysis;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysis;
use ModelSEED::MS::Types::ModelAnalysis;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelAnalysis::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelAnalysis';
    coerce 'ModelSEED::MS::ModelAnalysis::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelAnalysis->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelAnalysis',
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

