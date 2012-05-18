# Holder for ModelSEED::MS::FBASolution
package ModelSEED::MS::LazyHolder::FBASolution;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBASolution;
use ModelSEED::MS::Types::FBASolution;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBASolution::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBASolution';
    coerce 'ModelSEED::MS::FBASolution::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBASolution->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBASolution',
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

