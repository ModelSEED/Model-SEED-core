# Holder for ModelSEED::MS::Media
package ModelSEED::MS::LazyHolder::Media;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Media;
use ModelSEED::MS::Types::Media;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Media::Lazy',
        as 'ModelSEED::MS::LazyHolder::Media';
    coerce 'ModelSEED::MS::Media::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Media->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfMedia',
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

