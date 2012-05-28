# Holder for ModelSEED::MS::Model
package ModelSEED::MS::LazyHolder::Model;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Model;
use ModelSEED::MS::Types::Model;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Model::Lazy',
        as 'ModelSEED::MS::LazyHolder::Model';
    coerce 'ModelSEED::MS::Model::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Model->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModel',
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

