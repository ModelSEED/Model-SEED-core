# Holder for ModelSEED::MS::InstanceTransport
package ModelSEED::MS::LazyHolder::InstanceTransport;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::InstanceTransport;
use ModelSEED::MS::Types::InstanceTransport;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::InstanceTransport::Lazy',
        as 'ModelSEED::MS::LazyHolder::InstanceTransport';
    coerce 'ModelSEED::MS::InstanceTransport::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::InstanceTransport->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfInstanceTransport',
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

