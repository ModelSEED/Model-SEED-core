# Holder for ModelSEED::MS::ModelReactionRawGPR
package ModelSEED::MS::LazyHolder::ModelReactionRawGPR;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionRawGPR;
use ModelSEED::MS::Types::ModelReactionRawGPR;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelReactionRawGPR::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelReactionRawGPR';
    coerce 'ModelSEED::MS::ModelReactionRawGPR::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelReactionRawGPR->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelReactionRawGPR',
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

