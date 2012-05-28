# Holder for ModelSEED::MS::BiomassTemplateComponent
package ModelSEED::MS::LazyHolder::BiomassTemplateComponent;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::BiomassTemplateComponent;
use ModelSEED::MS::Types::BiomassTemplateComponent;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::BiomassTemplateComponent::Lazy',
        as 'ModelSEED::MS::LazyHolder::BiomassTemplateComponent';
    coerce 'ModelSEED::MS::BiomassTemplateComponent::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::BiomassTemplateComponent->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfBiomassTemplateComponent',
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

