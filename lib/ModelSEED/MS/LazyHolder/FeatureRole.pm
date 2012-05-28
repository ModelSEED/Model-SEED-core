# Holder for ModelSEED::MS::FeatureRole
package ModelSEED::MS::LazyHolder::FeatureRole;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FeatureRole;
use ModelSEED::MS::Types::FeatureRole;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FeatureRole::Lazy',
        as 'ModelSEED::MS::LazyHolder::FeatureRole';
    coerce 'ModelSEED::MS::FeatureRole::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FeatureRole->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFeatureRole',
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

