# Holder for ModelSEED::MS::ModelReactionProtein
package ModelSEED::MS::LazyHolder::ModelReactionProtein;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionProtein;
use ModelSEED::MS::Types::ModelReactionProtein;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelReactionProtein::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelReactionProtein';
    coerce 'ModelSEED::MS::ModelReactionProtein::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelReactionProtein->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelReactionProtein',
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

