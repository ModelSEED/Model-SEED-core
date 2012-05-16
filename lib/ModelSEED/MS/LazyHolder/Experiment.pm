# Holder for ModelSEED::MS::Experiment
package ModelSEED::MS::LazyHolder::Experiment;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Experiment;
use ModelSEED::MS::Types::Experiment;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Experiment::Lazy',
        as 'ModelSEED::MS::LazyHolder::Experiment';
    coerce 'ModelSEED::MS::Experiment::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Experiment->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfExperiment',
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

