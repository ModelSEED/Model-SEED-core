# Holder for ModelSEED::MS::BiomassTemplate
package ModelSEED::MS::LazyHolder::BiomassTemplate;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::BiomassTemplate;
use ModelSEED::MS::Types::BiomassTemplate;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::BiomassTemplate::Lazy',
        as 'ModelSEED::MS::LazyHolder::BiomassTemplate';
    coerce 'ModelSEED::MS::BiomassTemplate::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::BiomassTemplate->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfBiomassTemplate',
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

