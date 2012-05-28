# Holder for ModelSEED::MS::FBAResults
package ModelSEED::MS::LazyHolder::FBAResults;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAResults;
use ModelSEED::MS::Types::FBAResults;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAResults::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAResults';
    coerce 'ModelSEED::MS::FBAResults::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAResults->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAResults',
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

