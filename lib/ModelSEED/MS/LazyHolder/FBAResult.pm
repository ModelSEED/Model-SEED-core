# Holder for ModelSEED::MS::FBAResult
package ModelSEED::MS::LazyHolder::FBAResult;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAResult;
use ModelSEED::MS::Types::FBAResult;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAResult::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAResult';
    coerce 'ModelSEED::MS::FBAResult::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAResult->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAResult',
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

