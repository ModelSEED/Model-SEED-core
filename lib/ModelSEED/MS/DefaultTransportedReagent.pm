package ModelSEED::MS::DefaultTransportedReagent;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Data::Dumper;
$Data::Dumper::Maxdepth = 2;


has reaction_uuid => ( is => 'rw', isa => 'Str', required => 1);
has compound_uuid => ( is => 'rw', isa => 'Str', required => 1);
has compartment_uuid => ( is => 'rw', isa => 'Str', required => 1);
has compartmentIndex => ( is => 'rw', isa => 'Int', default => 0);
has transportCoefficient => ( is => 'rw', isa => 'Num', default => 1);
has isImport => ( is => 'rw', isa => 'Bool', default => 1);

has compound => ( is => 'rw', isa => 'ModelSEED::MS::Compound', required => 1, weak_ref => 1);
has reaction => ( is => 'rw', isa => 'ModelSEED::MS::Reaction', required => 1, weak_ref => 1);
has compartment => ( is => 'rw', isa => 'ModelSEED::MS::Compartment', required => 1, weak_ref => 1);

sub BUILDARGS {
    my ($self,$params) = @_;
    warn Dumper($params);
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    my $bio  = $params->{biochemistry};
    delete $params->{biochemistry};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    $params->{compound} = $bio->getCompound({ uuid => $params->{compound_uuid}});
    $params->{reaction} = $bio->getReaction({ uuid => $params->{reaction_uuid}});
    $params->{compartment} = $bio->getCompartment({ uuid => $params->{compartment_uuid}});
    delete $params->{relationships};
	return $params;
}

__PACKAGE__->meta->make_immutable;
1;
