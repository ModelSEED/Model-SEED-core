# Holder for ModelSEED::MS::FBAReactionVariable
package ModelSEED::MS::LazyHolder::FBAReactionVariable;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAReactionVariable;
use ModelSEED::MS::Types::FBAReactionVariable;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAReactionVariable::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAReactionVariable';
    coerce 'ModelSEED::MS::FBAReactionVariable::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAReactionVariable->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAReactionVariable',
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

