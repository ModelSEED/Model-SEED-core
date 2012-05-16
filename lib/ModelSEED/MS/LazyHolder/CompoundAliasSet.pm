# Holder for ModelSEED::MS::CompoundAliasSet
package ModelSEED::MS::LazyHolder::CompoundAliasSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundAliasSet;
use ModelSEED::MS::Types::CompoundAliasSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::CompoundAliasSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::CompoundAliasSet';
    coerce 'ModelSEED::MS::CompoundAliasSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::CompoundAliasSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompoundAliasSet',
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

