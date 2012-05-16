# Holder for ModelSEED::MS::User
package ModelSEED::MS::LazyHolder::User;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::User;
use ModelSEED::MS::Types::User;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::User::Lazy',
        as 'ModelSEED::MS::LazyHolder::User';
    coerce 'ModelSEED::MS::User::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::User->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfUser',
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

