package ModelSEED::ObjectManager; 
use Moose;
use ModelSEED::DB;
use namespace::autoclean;

my $types = [ qw( Annotation AnnotationFeature Biochemistry
    BiochemistryCompound BiochemistryCompoundAlias BiochemistryCompoundset
    BiochemistryMedia BiochemistryReaction BiochemistryReactionAlias
    BiochemistryReactionset Compartment Complex ComplexRole Compound
    CompoundAlias CompoundPk Compoundset CompoundsetCompound
    Feature Genome Mapping MappingCompartment MappingComplex MappingRole
    Media MediaCompound Model ModelCompartment ModelReaction
    ModelessFeature Modelfba ModelfbaCompound ModelfbaReaction 
    Permission Reaction ReactionAlias ReactionComplex ReactionCompound
    Reactionset ReactionsetReaction Role Roleset RolesetRole
)];

with 'ModelSEED::Role::ManagerRole' => { types => $types };

has db => ( is => 'rw', isa => 'ModelSEED::DB', builder => '_buildRDB', lazy => 1 );
has driver   => ( is => 'rw', isa => 'Str');
has database => ( is => 'rw', isa => 'Str');
has host     => ( is => 'rw', isa => 'Str');
has username => ( is => 'rw', isa => 'Str');
has server_time_zone => ( is => 'rw', isa => 'Str', default => 'UTC' );

has _managers => ( is => 'rw', isa => 'HashRef', default => sub { return {}; } );

sub _buildRDB {
    my $self = shift;
    my $params = {};
    foreach my $param (qw(driver database host username server_time_zone)) {
        $params->{$param} = $self->$param;
    }
    return ModelSEED::DB->new($params);
}

sub get_object {
    my $r = shift->get_objects(@_);
    return ($r > 0) ? $r->[0] : undef;
}

sub get_objects {
    my $self = shift;
    my $type = shift;
    my $cmd = "get_$type"."s";
    return $self->$cmd(@_);
}

__PACKAGE__->meta->make_immutable;
1;
