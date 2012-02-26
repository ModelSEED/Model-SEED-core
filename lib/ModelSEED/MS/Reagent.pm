package ModelSEED::MS::Reagent;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

has coefficient => ( is => 'rw', isa => 'Num', default => 1 );
has cofactor    => ( is => 'rw', isa => 'Bool', default => 0);
has compartmentIndex => ( is => 'rw', isa => 'Int', default => 0);
has compound_uuid => ( is => 'rw', isa => 'Str', required => 1);
has reaction_uuid => ( is => 'rw', isa => 'Str', required => 1);

has compound => ( is => 'rw', isa => 'ModelSEED::MS::Compound', required => 1, weak_ref => 1);
has default_transported_reagent => ( is => 'rw',
    isa => 'ModelSEED::MS::DefaultTransportedReagent');

sub BUILDARGS {
    my ($self,$params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    my $bio  = $params->{biochemistry};
    delete $params->{biochemistry};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    $params->{compound} = $bio->getCompound({ uuid => $params->{compound_uuid}});
    my $dtrData = $rels->{default_transported_reagent};
    $dtrData->{biochemistry} = $bio;
    $params->{default_transported_reagent} = 
        ModelSEED::MS::DefaultTransportedReagent->new($dtrData);
    delete $params->{relationships};
	return $params;
}

__PACKAGE__->meta->make_immutable;
1;
