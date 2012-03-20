




sub printMooseObject {
	my ($self,$args) = @_;
	my ($type,$baseObject,$attributes);
	
	
	#Printing header
	my $output = "########################################################################"."\n";
	$output .= "# ModelSEED::MS::".$type." - This is the moose object corresponding to the ".$type." object"."\n";
	$output .= "# Author: Christopher Henry, Scott Devoid, and Paul Frybarger"."\n";
	$output .= "# Contact email: chenry@mcs.anl.gov"."\n";
	$output .= "# Development location: Mathematics and Computer Science Division, Argonne National Lab"."\n";
	$output .= "# Date of module creation: ".DateTime->now()->datetime()."\n";
	$output .= "########################################################################"."\n";
	$output .= "use strict;"."\n";
	$output .= "package ModelSEED::MS::".$type.";"."\n";
	foreach my $oject (@{$subObjects}) {
		$output .= "use ModelSEED::MS::".$oject->{class}.";"."\n";
	}
	$output .= "use Moose;"."\n";
	$output .= "use namespace::autoclean;"."\n";
	$output .= "extends 'ModelSEED::MS::'".$baseObject.";"."\n\n";
	#Printing attributes
	$output .= "# Attributes"."\n";
	foreach my $attribute (@{$attributes}) {
		$output .= "has ".$attribute->{name}." => (is => '".$attribute->{permissions}."',isa => '".$attribute->{type}.$attribute->{builder}."');"."\n";
	}
	
	
	
	
	#Printing subobjects
	foreach my $oject (@{$subObjects}) {
		$output .= "has ".$boject->{name}." => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::".$boject->{type}."]');"."\n";
	}
	
	#Printing functions
	print $errorFH <<MSG;
sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    return $params;
}

sub BUILD {
    my ($self, $params) = @_;
    my $rels = $params->{relationships};
    if(defined($rels)) {
		my $subObjects = {
			compounds => "ModelSEED::MS::Compound",
            compartments => "ModelSEED::MS::Compartment",
			reactions => "ModelSEED::MS::Reaction",
			media => "ModelSEED::MS::Media",
			reactionsets => "ModelSEED::MS::Reactionset",
			compoundsets => "ModelSEED::MS::Compoundset",
		};
        my $order = [qw(compounds compartments reactions media reactionsets compoundsets)];
        foreach my $name (@$order) {
            my $values = $rels->{$name};
            $params->{$name} = [];
            my $class = $subObjects->{$name};
            my $objects = [];
            foreach my $data (@$values) {
                $data->{biochemistry} = $self;
                push(@$objects, $class->new($data));
            }
            $self->$name($objects);
		}
        delete $params->{relationships}
    }
}

MSG
	
	
}
	#Printing lazy builders
	
	
	
	$output .= "__PACKAGE__->meta->make_immutable;"."\n";
	$output .= "1;"."\n";
}






my $newAttribute = {
	name => ,
	type => ,
	permissions => "rw",
	builder => ""
};


my $objectDefinitions = {
	Annotation => {},
	Biochemistry => {},
	Biomass => {},
	BiomassCompound => {},
	Compartment => {},
	Complex => {},
	ComplexReactionRule => {},
	ComplexRole => {},
	Compound => {},
	Compoundset => {},
	CompoundStructure => {},
	CompoundPk => {},
	DefaultTransportedReagent => {},
	Feature => {},
	Genome => {},
	Mapping => {},
	Media => {},
	MediaCompound => {},
	Model => {},
	ModelCompartment => {},
	ModelessFeature => {},
	Modelfba => {},
	ModelfbaCompound => {},
	ModelfbaReaction => {},
	ModelReaction => {},
	ModelReactionRawGPR => {},
	ModelTransportedReagent => {},
	Reaction => {},
	ReactionRule => {},
	ReactionRuleTransport => {},
	ReactionSet => {},
	Reagent => {},
	ReagentTransport => {},
	Role => {},
	Roleset => {},
	RolesetRole => {}
};

$objectDefinitions->{Biochemistry} = {
	parents => [],
	class => 'root',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'public',perm => 'rw',type => 'Int',req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
	],
	subobjects => [
		{name => "aliases",class => "BiochemistryAlias",type => "hasharray(username,id)"},
		{name => "compartments",class => "Compartment",type => "child"},
		{name => "compounds",class => "Compound",type => "child"},
		{name => "reactions",class => "Reaction",type => "child"},
		{name => "media",class => "Media",type => "child"},
		{name => "compoundsets",class => "Compoundset",type => "child"},
		{name => "reactionsets",class => "Reactionset",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Compartment} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 2,req => 1},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Compound} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'abbreviation',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'cksum',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'unchargedFormula',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'formula',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'mass',perm => 'rw',type => 'Num',req => 0},
		{name => 'defaultCharge',perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaG',perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [
		{name => "aliases",class => "CompoundAlias",type => "hasharray(type,alias)"},
		{name => "structures",class => "CompoundStructure",type => "encompassed"},
		{name => "pks",class => "CompoundPk",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{CompoundStructure} = {
	parents => ['Compound'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'structure',perm => 'rw',type => 'Str',req => 1},
		{name => 'cksum',perm => 'rw',type => 'Str',len => 255,req => 1},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(type cksum compound_uuid) ],
	links => []
};

$objectDefinitions->{CompoundPk} = {
	parents => ['Compound'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',len => 45,req => 0},
		{name => 'atom',perm => 'rw',type => 'Int',req => 0},
		{name => 'pk',perm => 'rw',type => 'Num',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 1,req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(compound_uuid atom type) ],
	links => []
};

$objectDefinitions->{Reaction} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'abbreviation',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'cksum',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'equation',perm => 'rw',type => 'Str',req => 0},
		{name => 'deltaG',perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',perm => 'rw',type => 'Num',req => 0},
		{name => 'reversibility',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'thermoReversibility',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'defaultProtons',perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [
		{name => "aliases",class => "ReactionAlias",type => "hasharray(type,alias)"},
		{name => "instances",class => "ReactionInstance",type => "encompassed"},
		{name => "reagents",class => "Reagent",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Reagent} = {
	parents => ['Reaction'],
	class => 'encompassed',
	attributes => [
		{name => 'reaction_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 0},
		{name => 'cofactor',perm => 'rw',type => 'Int',req => 0},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},#0 for not transported,>0 for transported
	],
	subobjects => [],
	primarykeys => [ qw(reaction_uuid compound_uuid compartmentIndex) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"}
	]
};

$objectDefinitions->{ReactionInstance} = {
	parents => ['Reaction'],
	class => 'encompassed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'reaction_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'equation',perm => 'rw',type => 'Str',len => 255,req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'Str',len => 36,req => 1}
	],
	subobjects => [
		{name => "aliases",class => "ReactionInstanceAlias",type => "hasharray(type,alias)"},
		{name => "transports",class => "DefaultTransports",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"}
	]
};

$objectDefinitions->{InstanceTransports} = {
	parents => ['ReactionInstance'],
	class => 'encompassed',
	attributes => [
		{name => 'reactiondefault_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Int',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(compound_uuid reactiondefault_uuid compartmentIndex) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"}
	]
};

$objectDefinitions->{Media} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 1,req => 0},#minimal,defined,predictedminimal,undefined
	],
	subobjects => [
		{name => "mediacompounds",class => "MediaCompound",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{MediaCompound} = {
	parents => ['Media'],
	class => 'encompassed',
	attributes => [
		{name => 'media_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'concentration',perm => 'rw',type => 'Num',req => 0},
		{name => 'maxFlux',perm => 'rw',type => 'Num',req => 0},
		{name => 'minFlux',perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(media_uuid compound_uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"},
	]
};

$objectDefinitions->{Compoundset} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'searchname',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'class',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 0},
	],
	subobjects => [
		{name => "compounds",class => "CompoundsetCompound",type => "link",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"}
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Reactionset} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'searchname',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'class',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 0},
	],
	subobjects => [
		{name => "reactions",class => "ReactionsetReaction",type => "link",attribute => "reaction_uuid",parent => "Biochemistry",class => "Reaction",query => "uuid"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Model} = {
	parents => ['ObjectManager'],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'public',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'version',perm => 'rw',type => 'Int',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'status',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'reactions',perm => 'rw',type => 'Int',req => 0},
		{name => 'compounds',perm => 'rw',type => 'Int',req => 0},
		{name => 'annotations',perm => 'rw',type => 'Int',req => 0},
		{name => 'growth',perm => 'rw',type => 'Num',req => 0},
		{name => 'current',perm => 'rw',type => 'Int',req => 0},
		{name => 'mapping_uuid',perm => 'rw',type => 'Str',len => 36,req => 0},
		{name => 'biochemistry_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'annotation_uuid',perm => 'rw',type => 'Str',len => 36,req => 0},
	],
	subobjects => [
		{name => "biomasses",class => "Biomass",type => "child"},
		{name => "modelcompartments",class => "ModelCompartment",type => "child"},
		{name => "modelcompounds",class => "ModelCompound",type => "child"},
		{name => "modelreactions",class => "ModelReaction",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "biochemistry",attribute => "biochemistry_uuid",parent => "ObjectManager",class => "Biochemistry",query => "uuid"},
		{name => "mapping",attribute => "mapping_uuid",parent => "ObjectManager",class => "Mapping",query => "uuid"},
		{name => "annotation",attribute => "annotation_uuid",parent => "ObjectManager",class => "Annotation",query => "uuid"},
	]
};

$objectDefinitions->{Biomass} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
	],
	subobjects => [
		{name => "biomasscompounds",class => "BiomassCompound",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{BiomassCompound} = {
	parents => ['Biomass'],
	class => 'encompassed',
	attributes => [
		{name => 'biomass_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(biomass_uuid modelcompound_uuid) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",class => "ModelCompound",query => "uuid"},
	]
};

$objectDefinitions->{ModelCompartment} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 1},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'model_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'label',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'pH',perm => 'rw',type => 'Num',req => 0},
		{name => 'potential',perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"}
	]
};

$objectDefinitions->{ModelCompound} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'model_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'charge',perm => 'rw',type => 'Num',req => 0},
		{name => 'formula',perm => 'rw',type => 'Str',req => 0},
		{name => 'model_compartment_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(model_uuid uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"},
		{name => "modelcompartment",attribute => "model_compartment_uuid",parent => "Model",class => "ModelCompartment",query => "uuid"}
	]
};

$objectDefinitions->{ModelReaction} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'model_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'reaction_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'protons',perm => 'rw',type => 'Num',req => 0},
		{name => 'model_compartment_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
	],
	subobjects => [
		{name => "gpr",class => "ModelReactionRawGPR",type => "encompassed"},
		{name => "transports",class => "ModelReactionTransports",type => "encompassed"},
	],
	primarykeys => [ qw(model_uuid uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",class => "Reaction",query => "uuid"},
		{name => "modelcompartment",attribute => "model_compartment_uuid",parent => "Model",class => "ModelCompartment",query => "uuid"}
	]
};

$objectDefinitions->{ModelReactionRawGPR} = {
	parents => ['ModelReaction'],
	class => 'encompassed',
	attributes => [
		{name => 'model_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'isCustomGPR',perm => 'rw',type => 'Int',req => 0},
		{name => 'rawGPR',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(model_uuid modelreaction_uuid) ],
	links => []
};

$objectDefinitions->{ModelReactionTransports} = {
	parents => ['ModelReaction'],
	class => 'encompassed',
	attributes => [
		{name => 'model_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Int',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(model_uuid modelreaction_uuid compound_uuid compartmentIndex) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",class => "ModelCompound",query => "uuid"},
	]
};

$objectDefinitions->{Modelfba} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 1},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
		{name => 'description',perm => 'rw',type => 'Str',req => 0},
		{name => 'model_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'media_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'expressionData_uuid',perm => 'rw',type => 'Str',len => 36,req => 0},
		{name => 'regmodel_uuid',perm => 'rw',type => 'Str',len => 36,req => 0},
		{name => 'geneko',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'reactionko',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'drainRxn',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'growthConstraint',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'uptakeLimits',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'thermodynamicConstraints',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'allReversible',perm => 'rw',type => 'Int',len => 255,req => 0},
	],
	subobjects => [
		{name => "compounds",class => "ModelfbaCompound",type => "encompassed"},
		{name => "reactions",class => "ModelfbaReaction",type => "encompassed"},
		{name => "genes",class => "ModelfbaFeature",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "media",attribute => "media_uuid",parent => "Biochemistry",class => "Media",query => "uuid"}
	]
};

$objectDefinitions->{ModelfbaCompound} = {
	parents => ['Modelfba'],
	class => 'encompassed',
	attributes => [
		{name => 'modelfba_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'flux',perm => 'rw',type => 'Num',req => 0},
		{name => 'lowerbound',perm => 'rw',type => 'Num',req => 0},
		{name => 'upperbound',perm => 'rw',type => 'Num',req => 0},
		{name => 'min',perm => 'rw',type => 'Num',req => 0},
		{name => 'max',perm => 'rw',type => 'Num',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'ko',perm => 'rw',type => 'Int',req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(modelfba_uuid modelcompound_uuid) ],
	links => [
		{name => "compound",attribute => "modelcompound_uuid",parent => "Model",class => "ModelCompound",query => "uuid"},
	]
};

$objectDefinitions->{ModelfbaReaction} = {
	parents => ['Modelfba'],
	class => 'encompassed',
	attributes => [
		{name => 'modelfba_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'flux',perm => 'rw',type => 'Num',req => 0},
		{name => 'lowerbound',perm => 'rw',type => 'Num',req => 0},
		{name => 'upperbound',perm => 'rw',type => 'Num',req => 0},
		{name => 'min',perm => 'rw',type => 'Num',req => 0},
		{name => 'max',perm => 'rw',type => 'Num',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'ko',perm => 'rw',type => 'Int',req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(modelfba_uuid modelreaction_uuid) ],
	links => [
		{name => "reaction",attribute => "modelreaction_uuid",parent => "Model",class => "ModelReaction",query => "uuid"},
	]
};

$objectDefinitions->{ModelfbaFeature} = {
	parents => ['Modelfba'],
	class => 'encompassed',
	attributes => [
		{name => 'modelfba_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'feature_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'growthFraction',perm => 'rw',type => 'Num',req => 0},
		{name => 'essential',perm => 'rw',type => 'Int',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',req => 0},
		{name => 'activity',perm => 'rw',type => 'Num',req => 0},
		{name => 'ko',perm => 'rw',type => 'Int',req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(modelfba_uuid feature_uuid) ],
	links => [
		{name => "feature",attribute => "feature_uuid",parent => "Annotation",class => "Feature",query => "uuid"},
	]
};

$objectDefinitions->{Annotation} = {
	parents => ['ObjectManager'],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'genome_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'mapping_uuid',perm => 'rw',type => 'Str',len => 36,req => 1}
	],
	subobjects => [
		{name => "genomes",class => "Genome",type => "child"},
		{name => "features",class => "Feature",type => "child"}
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "mapping",attribute => "mapping_uuid",parent => "ObjectManager",class => "Mapping",query => "uuid"},
	]
};

$objectDefinitions->{Genome} = {
	parents => ['Annotation'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'public',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'source',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'taxonomy',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'cksum',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'size',perm => 'rw',type => 'Int',req => 0},
		{name => 'genes',perm => 'rw',type => 'Int',req => 0},
		{name => 'gc',perm => 'rw',type => 'Num',req => 0},
		{name => 'gramPositive',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'aerobic',perm => 'rw',type => 'Str',len => 1,req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Feature} = {
	parents => ['Annotation'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'cksum',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'genome_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'start',perm => 'rw',type => 'Int',req => 0},
		{name => 'stop',perm => 'rw',type => 'Int',req => 0},
	],
	subobjects => [
		{name => "roles",class => "FeatureRoles",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "genome",attribute => "genome_uuid",parent => "Annotation",class => "Genome",query => "uuid"},
	]
};

$objectDefinitions->{FeatureRoles} = {
	parents => ['Feature'],
	class => 'encompassed',
	attributes => [
		{name => 'annotation_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'feature_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'role_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'complete_string',perm => 'rw',type => 'Str'},
	],
	subobjects => [],
	primarykeys => [ qw(annotation_uuid feature_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",class => "Role",query => "uuid"},
	]
};

$objectDefinitions->{Mapping} = {
	parents => ['ObjectManager'],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'public',perm => 'rw',type => 'Int',req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'biochemistry_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
	],
	subobjects => [
		{name => "roles",class => "Role",type => "child"},
		{name => "rolesets",class => "Roleset",type => "child"},
		{name => "reactionrules",class => "ReactionRule",type => "child"},
		{name => "complexes",class => "Complex",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "biochemistry",attribute => "biochemistry_uuid",parent => "ObjectManager",class => "Biochemistry",query => "uuid"},
	]
};

$objectDefinitions->{Role} = {
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',req => 0},
		{name => 'searchname',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'seedfeature',perm => 'rw',type => 'Str',len => 36,req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Roleset} = {
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'public',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'searchname',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'class',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'subclass',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 0}
	],
	subobjects => [
		{name => "roles",class => "RolesetRole",type => "link",attribute => "role_uuid",parent => "Mapping",class => "Role",query => "uuid"}
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ReactionRule} = {
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'reaction_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'transprotonNature',perm => 'rw',type => 'Str',len => 255,req => 0}
	],
	subobjects => [
		{name => "ReactionRuleTransport",class => "ReactionRuleTransport",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",class => "Reaction",query => "uuid"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"}
	]
};

$objectDefinitions->{ReactionRuleTransport} = {
	parents => ['ReactionRule'],
	class => 'encompassed',
	attributes => [
		{name => 'reaction_rule_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Int',req => 1}
	],
	subobjects => [],
	primarykeys => [ qw(reaction_rule_uuid compartmentIndex) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"}
	]
};

$objectDefinitions->{Complex} = {
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'name',perm => 'rw',type => 'Str',len => 255,req => 0},
		{name => 'searchname',perm => 'rw',type => 'Str',len => 255,req => 0}
	],
	subobjects => [
		{name => "reactionrules",class => "ComplexReactionRule",type => "link",attribute => "reaction_rule_uuid",parent => "Mapping",class => "ReactionRule",query => "uuid"},
		{name => "complexroles",class => "ComplexRole",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ComplexRole} = {
	parents => ['Complex'],
	class => 'encompassed',
	attributes => [
		{name => 'complex_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'role_uuid',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'optional',perm => 'rw',type => 'Int',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',len => 1,req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",class => "Role",query => "uuid"}
	]
};