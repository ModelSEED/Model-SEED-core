# Holder for ModelSEED::MS::ComplexAliasSet
package ModelSEED::MS::LazyHolder::ComplexAliasSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexAliasSet;
use ModelSEED::MS::Types::ComplexAliasSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ComplexAliasSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::ComplexAliasSet';
    coerce 'ModelSEED::MS::ComplexAliasSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ComplexAliasSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfComplexAliasSet',
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

