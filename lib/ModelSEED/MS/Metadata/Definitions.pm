use strict;
package ModelSEED::MS::DB::Definitions;

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
	parents => ["ObjectManager"],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Bool',req => 0,default => "1"},
		{name => 'public',perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
	],
	subobjects => [
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
		{name => 'uuid',perm => 'rw',type => 'uuid',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 2,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Compound} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'uuid',len => 36,req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'abbreviation',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'cksum',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'unchargedFormula',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'formula',perm => 'rw',type => 'varchar',req => 0,default => ""},
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
		{name => 'compound_uuid',perm => 'rw',type => 'uuid',len => 36,req => 1},
		{name => 'structure',perm => 'rw',type => 'Str',req => 1},
		{name => 'cksum',perm => 'rw',type => 'varchar',req => 0,default => ""},
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
		{name => 'compound_uuid',perm => 'rw',type => 'uuid',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',len => 45,req => 0},
		{name => 'atom',perm => 'rw',type => 'Int',req => 0},
		{name => 'pk',perm => 'rw',type => 'Num',req => 1},
		{name => 'type',perm => 'rw',type => 'Str',len => 1,req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(compound_uuid atom type) ],
	links => []
};

$objectDefinitions->{Reaction} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'uuid',len => 36,req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'abbreviation',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'cksum',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'deltaG',perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',perm => 'rw',type => 'Num',req => 0},
		{name => 'reversibility',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
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
		{name => 'reaction_uuid',perm => 'rw',type => 'uuid',len => 36,req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'uuid',len => 36,req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
		{name => 'cofactor',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1,default => "0"},#0 for not transported,>0 for transported
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
		{name => 'uuid',perm => 'rw',type => 'uuid',len => 36,req => 0},
		{name => 'reaction_uuid',perm => 'rw',type => 'uuid',len => 36,req => 1},
		{name => 'equation',perm => 'rw',type => 'varchar',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'uuid',len => 36,req => 1}
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
		{name => 'reactioninstance_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'type',perm => 'rw',type => 'Str',len => 1,req => 0,default => "unknown"},#minimal,defined,predictedminimal,undefined,unknown
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
		{name => 'media_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'concentration',perm => 'rw',type => 'Num',req => 0,default => "0.001"},
		{name => 'maxFlux',perm => 'rw',type => 'Num',req => 0,default => "100"},
		{name => 'minFlux',perm => 'rw',type => 'Num',req => 0,default => "-100"},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'class',perm => 'rw',type => 'varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'class',perm => 'rw',type => 'varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'varchar',req => 1},
		{name => 'name',perm => 'rw',type => 'Str',len => 32,req => 0,default => ""},
		{name => 'version',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 0,default => "Singlegenome"},
		{name => 'status',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'reactions',perm => 'rw',type => 'Int',req => 0},
		{name => 'compounds',perm => 'rw',type => 'Int',req => 0},
		{name => 'annotations',perm => 'rw',type => 'Int',req => 0},
		{name => 'growth',perm => 'rw',type => 'Num',req => 0},
		{name => 'current',perm => 'rw',type => 'Int',req => 0,default => "1"},
		{name => 'mapping_uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'biochemistry_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'annotation_uuid',perm => 'rw',type => 'uuid',req => 0},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
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
		{name => 'biomass_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'model_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'label',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'pH',perm => 'rw',type => 'Num',req => 0,default => "7"},
		{name => 'potential',perm => 'rw',type => 'Num',req => 0,default => "0"},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'model_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'charge',perm => 'rw',type => 'Num',req => 0},
		{name => 'formula',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'model_compartment_uuid',perm => 'rw',type => 'uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'model_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'reaction_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'protons',perm => 'rw',type => 'Num',req => 0},
		{name => 'model_compartment_uuid',perm => 'rw',type => 'uuid',req => 1},
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
		{name => 'model_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'isCustomGPR',perm => 'rw',type => 'Int',req => 0,default => "1"},
		{name => 'rawGPR',perm => 'rw',type => 'Str',req => 0,default => "UNKNOWN"},
	],
	subobjects => [],
	primarykeys => [ qw(model_uuid modelreaction_uuid) ],
	links => []
};

$objectDefinitions->{ModelReactionTransports} = {
	parents => ['ModelReaction'],
	class => 'encompassed',
	attributes => [
		{name => 'model_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'varchar',req => 1,default => ""},
		{name => 'type',perm => 'rw',type => 'Str',req => 1},
		{name => 'description',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'model_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'media_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'expressionData_uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'regmodel_uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'geneko',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'reactionko',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'drainRxn',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'growthConstraint',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'uptakeLimits',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'thermodynamicConstraints',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'allReversible',perm => 'rw',type => 'Int',len => 255,req => 0,default => "0"},
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
		{name => 'modelfba_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'flux',perm => 'rw',type => 'Num',req => 0},
		{name => 'lowerbound',perm => 'rw',type => 'Num',req => 1},
		{name => 'upperbound',perm => 'rw',type => 'Num',req => 1},
		{name => 'min',perm => 'rw',type => 'Num',req => 0},
		{name => 'max',perm => 'rw',type => 'Num',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'ko',perm => 'rw',type => 'Int',req => 0,default => "0"}
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
		{name => 'modelfba_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'flux',perm => 'rw',type => 'Num',req => 0},
		{name => 'lowerbound',perm => 'rw',type => 'Num',req => 1},
		{name => 'upperbound',perm => 'rw',type => 'Num',req => 1},
		{name => 'min',perm => 'rw',type => 'Num',req => 0},
		{name => 'max',perm => 'rw',type => 'Num',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'ko',perm => 'rw',type => 'Int',req => 0,default => "0"}
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
		{name => 'modelfba_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'feature_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'growthFraction',perm => 'rw',type => 'Num',req => 0},
		{name => 'essential',perm => 'rw',type => 'Int',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',req => 0},
		{name => 'activity',perm => 'rw',type => 'Num',req => 0},
		{name => 'ko',perm => 'rw',type => 'Int',req => 0,default => "0"}
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'mapping_uuid',perm => 'rw',type => 'uuid'}
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'source',perm => 'rw',type => 'varchar',req => 1},
		{name => 'class',perm => 'rw',type => 'varchar',req => 0,default => ""},#gramPositive,gramNegative,archaea,eurkaryote
		{name => 'taxonomy',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'cksum',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'size',perm => 'rw',type => 'Int',req => 0},
		{name => 'genes',perm => 'rw',type => 'Int',req => 0},
		{name => 'gc',perm => 'rw',type => 'Num',req => 0},
		{name => 'etcType',perm => 'rw',type => 'varchar',len => 1,req => 0},#aerobe,facultativeAnaerobe,obligateAnaerobe
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Feature} = {
	parents => ['Annotation'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'cksum',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'genome_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'start',perm => 'rw',type => 'Int',req => 0},
		{name => 'stop',perm => 'rw',type => 'Int',req => 0},
		{name => 'contig',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [
		{name => "featureroles",class => "FeatureRoles",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "genome",attribute => "genome_uuid",parent => "Annotation",class => "Genome",query => "uuid"},
	]
};

$objectDefinitions->{FeatureRole} = {
	parents => ['Feature'],
	class => 'encompassed',
	attributes => [
		{name => 'feature_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'role_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compartment',perm => 'rw',type => 'Str',default => "unknown"},
		{name => 'comment',perm => 'rw',type => 'Str',default => ""},
		{name => 'delimiter',perm => 'rw',type => 'Str',default => ""},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'biochemistry_uuid',perm => 'rw',type => 'uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'varchar',req => 0,default => ""},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'class',perm => 'rw',type => 'varchar',req => 0,default => "unclassified"},
		{name => 'subclass',perm => 'rw',type => 'varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1}
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'reaction_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'transprotonNature',perm => 'rw',type => 'varchar',req => 0,default => ""}
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
		{name => 'reaction_rule_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'varchar',req => 0,default => ""}
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
		{name => 'complex_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'role_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'optional',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'type',perm => 'rw',type => 'Str',len => 1,req => 0,default => "G"}
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",class => "Role",query => "uuid"}
	]
};

sub objectDefinitions {
	return $objectDefinitions;
}

1;