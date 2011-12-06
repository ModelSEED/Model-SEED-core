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

has db => ( is => 'rw', isa => 'Rose::DB', default => sub { return ModelSEED::DB->new(); });
has _managers => ( is => 'rw', isa => 'HashRef', default => sub { return {}; } );

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
