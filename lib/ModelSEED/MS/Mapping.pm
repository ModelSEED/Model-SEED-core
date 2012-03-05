package ModelSEED::MS::Mapping;
use Moose;
use namespace::autoclean;
use DateTime;
use Data::UUID;
use ModelSEED::MS::Complex;
use ModelSEED::MS::Role;
use ModelSEED::MS::ReactionRule;
use ModelSEED::MS::Biochemistry;

#Parent object link
has om => (is => 'rw', isa => 'ModelSEED::CoreApi');

#Attributes
has uuid => ( is => 'rw', isa => 'Str', builder => '_buildUUID');
has modDate => ( is => 'rw', isa => 'DateTime', builder => '_buildDate');
has locked => ( is => 'rw', isa => 'Bool', default => 0);
has public => ( is => 'rw', isa => 'Bool', default => 0);
has name   => ( is => 'rw', isa => 'Str', default => '');
has biochemistry_uuid  => (is => 'rw',isa => 'Str',builder => '_buildRole',lazy => 1);

# Subobjects
has biochemistry  => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry',builder => '_buildBiochemistry',lazy => 1);
has reactionRules => ( is => 'rw',isa => 'ArrayRef | ArrayRef[ModelSEED::MS::ReactionRule]');
has complexes => ( is => 'rw',isa => 'ArrayRef | ArrayRef[ModelSEED::MS::Complex]');
has roles => ( is => 'rw',isa => 'ArrayRef | ArrayRef[ModelSEED::MS::Role]');
   
# Constants
has dbAttributes => (is => 'ro',isa => 'ArrayRef[Str]',builder => '_buildDbAttributes');
has _typesHash => (is => 'ro',isa => 'HashRef[Str]',builder => '_buildTypesHash');
has _type => (is => 'ro',isa => 'Str',default => 'Mapping');
has _relToClass => ( # mapps relName => MS::Object class
    is => 'ro', init_arg => undef, lazy => 1,
    builder => '_build_relToClass'
);

sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    if (defined($params->{model}) && defined($params->{model}->biochemistry()) && $params->{model}->biochemistry()->uuid() eq $params->{biochemistry_uuid}) {
    	$params->{biochemistry} = $params->{model}->biochemistry();
    } elsif (defined($params->{biochemistry}) && $params->{biochemistry}->uuid() ne $params->{biochemistry_uuid}) {
    	delete $params->{biochemistry};
    }
    return $params;
}

sub BUILD {
    my ($self, $params) = @_;
    my $rels = $params->{relationships};
    if(defined($rels)) {
		my $subObjects = {
			reactionrules => ["reactionRules","ModelSEED::MS::ReactionRule"],
		    roles => ["roles","ModelSEED::MS::Role"],
		    complexes => ["complexes","ModelSEED::MS::Complex"],
		};
        my $order = [qw( reactionrules roles complexes )];
        foreach my $name (@$order) {
            if (defined($rels->{$name})) {
	            my $values = $rels->{$name};
	            my $function = $subObjects->{$name}->[0];
	            my $class = $subObjects->{$name}->[1];
	            my $objects = [];
            	foreach my $data (@$values) {
	                $data->{model} = $self;
	                push(@$objects, $class->new($data));
	            }
	            $self->$function($objects);
            }
		}
        delete $params->{relationships}
    }
}

sub printToFile {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{filename => undef});
	my $data = ["Attributes{"];
	my $printedAtt = $self->_printedAttributes();
	for (my $i=0; $i < @{$printedAtt}; $i++) {
		my $att = $printedAtt->[$i];
		push(@{$data},$att."\t".$self->$att());
	}
	push(@{$data},"}");
	push(@{$data},"ReactionRules{");
	push(@{$data},"Rule ID\tID\tDirection\tCompartment\tTransproton nature\tTransport");
	foreach my $rule (@{$self->reactionRules()}) {
		push(@{$data},$rule->uuid()."\t".$rule->reaction()->id()."\t".$rule->direction()."\t".$rule->compartment()->id()."\t".$rule->transprotonNature()."\t".$rule->transportString());
	}
	push(@{$data},"}");
	push(@{$data},"Complexes{");
	push(@{$data},"ID\tName\tRules\tRoles");
	foreach my $complex (@{$self->complexes()}) {
		push(@{$data},$complex->id()."\t".$complex->name()."\t".$complex->ruleString()."\t".$complex->roleString());
	}
	push(@{$data},"}");
	push(@{$data},"Roles{");
	push(@{$data},"ID\tName\tExemplar");
	foreach my $role (@{$self->roles()}) {
		push(@{$data},$role->id()."\t".$role->name()."\t".$role->feature_uuid());
	}
	push(@{$data},"}");
	if (defined($args->{filename})) {
		ModelSEED::utilities::PRINTFILE($args->{filename},$data);
	}
	return $data;
}

# BULDER FUNCTIONS
sub _buildBiochemistry {
	my ($self) = @_;
	if (defined($self->om())) {
        my $data = $self->om()->getBiochemistry({
	    	uuid => $self->biochemistry_uuid(),
			with_all => 1
	    });
	    if (!defined($data)) {
	    	ModelSEED::utilities::ERROR("Biochemistry ".$self->biochemistry_uuid()." not found!");
	    }
	    $data->{om} = $self->api();
	    return ModelSEED::MS::Biochemistry->new($data);
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve biochemistry without object manager!");
    }
}

sub _buildTypesHash {
	return {
		Biochemistry => "biochemistry",
		ReactionRule => "reactionRules",
		Complex => "complexes",
		Role => "roles"
    }; 
}

has uuid => ( is => 'rw', isa => 'Str', builder => '_buildUUID');
has modDate => ( is => 'rw', isa => 'DateTime', builder => '_buildDate');
has locked => ( is => 'rw', isa => 'Bool', default => 0);
has public => ( is => 'rw', isa => 'Bool', default => 0);
has name   => ( is => 'rw', isa => 'Str', default => '');
has biochemistry_uuid  => (is => 'rw',isa => 'Str',builder => '_buildRole',lazy => 1);

sub _printedAttributes { return [ qw( uuid name biochemistry_uuid public ) ]; }
sub _buildDbAttributes { return [ qw( uuid name biochemistry_uuid public modDate locked ) ]; }
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

