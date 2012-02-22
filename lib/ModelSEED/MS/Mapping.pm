package ModelSEED::MS::Mapping;
use Moose;
use namespace::autoclean;
use DateTime;
use Data::UUID;
use ModelSEED::MS::Complex;

has _relToClass => ( # mapps relName => MS::Object class
    is => 'ro', init_arg => undef, lazy => 1,
    builder => '_build_relToClass'
);

# Basic attributes
has type => ( is => 'ro', isa => 'Str', default => 'Mapping');
has uuid => ( is => 'rw', isa => 'Str', builder => '_buildUUID');
has modDate => ( is => 'rw', isa => 'DateTime', builder => '_buildDate');
has locked => ( is => 'rw', isa => 'Bool', default => 0);
has public => ( is => 'rw', isa => 'Bool', default => 0);
has name   => ( is => 'rw', isa => 'Str', default => '');
# Relationships
#has reaction_rules => ( is => 'rw',
#    isa => 'ArrayRef | Array[ModelSEED::MS::ReactionRule]',
#    builder => '_buildReactionRules', lazy => 1 );
has complexes => ( is => 'rw', isa => 'ArrayRef | Array[ModelSEED::MS::Complex]');
#has roles => ( is => 'rw',
#    isa => 'ArrayRef | Array[ModelSEED::MS::Role]',
#    builder => '_buildRole', lazy => 1 );


sub BUILDARGS {
    my ($self, $params) = @_;
    foreach my $attr (keys %{$params->{attributes}}) {
        $params->{$attr} = $params->{attributes}->{$attr};
    }
    delete $params->{attributes};
    return $params;
}

$mapping->complex()
around 'complexes' => sub {
    my ($orig, $self) = @_;
    my $data = $self->orig();
    if(defined($data->[0]) &&
        ref($data->[0]) eq 'HASH') {
        map { $_ = ModelSEED::MS::Complex->new($_) } @$data;
        warn "initializing complexes";
    }
    return $data;
}


         


# BULDER FUNCTIONS
sub _buildUUID { return Data::UUID->new()->create()->to_string(); }
sub _buildDate { return DateTime->now(); }
sub _build_relToClass {
    return {
        complexes => 'ModelSEED::MS::Complex',
        reaction_rules => 'ModelSEED::MS::ReactionRule',
        mapping_aliases => 'ModelSEED::MS::MappingAlias',
        roles => 'ModelSEED::MS::Role',
    };
}
__PACKAGE__->meta->make_immutable;
1;

