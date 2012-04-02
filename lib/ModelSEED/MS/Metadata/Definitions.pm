use strict;
package ModelSEED::MS::DB::Definitions;

my $objectDefinitions = {};

$objectDefinitions->{Genome} = {
	parents => ['ObjectManager'],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'source',perm => 'rw',type => 'ModelSEED::varchar',req => 1},
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},#gramPositive,gramNegative,archaea,eurkaryote
		{name => 'taxonomy',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'cksum',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'size',perm => 'rw',type => 'Int',req => 0},
		{name => 'gc',perm => 'rw',type => 'Num',req => 0},
		{name => 'etcType',perm => 'rw',type => 'ModelSEED::varchar',len => 1,req => 0},#aerobe,facultativeAnaerobe,obligateAnaerobe
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Strain} = {
	parents => ['Genome'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'source',perm => 'rw',type => 'ModelSEED::varchar',req => 1},
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
	],
	subobjects => [
		{name => "deletions",class => "Deletion",type => "child"},
		{name => "insertions",class => "Insertion",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Deletion} = {
	parents => ['Genome'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'start',perm => 'rw',type => 'Int',req => 0},
		{name => 'stop',perm => 'rw',type => 'Int',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Insertion} = {
	parents => ['Genome'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'insertionTarget',perm => 'rw',type => 'Int',req => 0},
		{name => 'sequence',perm => 'rw',type => 'Str',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Experiment} = {
	parents => ["ObjectManager"],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'genome_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},#I think this should be Strain.Right now, we’re linking an experiment to a single GenomeUUID here, but I think it makes more sense to link to a single StrainUUID, which is what we do in the Price DB.  
		{name => 'name',perm => 'rw',type => 'Str',req => 0},
		{name => 'description',perm => 'rw',type => 'Str',req => 0},
		{name => 'institution',perm => 'rw',type => 'Str',req => 0},
		{name => 'source',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		 {name => "genome",attribute => "genome_uuid",parent => "ObjectManager",class => "Genome",query => "uuid"},
	]
};

$objectDefinitions->{ExperimentDataPoint} = {
	parents => ["Experiment"],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'strain_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},#Not needed if it’s in the experiment table? I think we need to be consistent in defining where in these tables to put e.g. genetic perturbations done in an experiment.
		{name => 'media_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'pH',perm => 'rw',type => 'Num',req => 0},
		{name => 'temperature',perm => 'rw',type => 'Num',req => 0},
		{name => 'buffers',perm => 'rw',type => 'Str',req => 0},#There could be multiple buffers in a single media. Would this be listed in the Media table? Multiple buffers in single media isn’t something we’ve run across yet and seems like a rarity at best, since their purpose is maintaining pH.  We discussed just listing the buffer here, without amount, because the target pH should dictate the amount of buffer. 
		{name => 'phenotype',perm => 'rw',type => 'Str',req => 0},
		{name => 'notes',perm => 'rw',type => 'Str',req => 0},
		{name => 'growthMeasurement',perm => 'rw',type => 'Num',req => 0},#Would these be better in their own table? IT’s just another type of measurement just like the flux, metabolite, etc... One reason to keep the growth measurements here is unit consistency; moving them to the other table with the other flux measurements would require a clear division between growth rates and secretion/uptake rates to distinguish between 1/h and mmol/gDW/h. Rather than do that, I think keeping them in separate tables makes for an easy, logical division. 
		{name => 'growthMeasurementType',perm => 'rw',type => 'Str',req => 0},#Would these be better in their own table?
	],
	subobjects => [
		{name => "fluxMeasurements",class => "FluxMeasurement",type => "child"},
		{name => "uptakeMeasurements",class => "UptakeMeasurement",type => "child"},
		{name => "metaboliteMeasurements",class => "MetaboliteMeasurement",type => "child"},
		{name => "geneMeasurements",class => "GeneMeasurement",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "strain",attribute => "strain_uuid",parent => "Genome",class => "Strain",query => "uuid"},
		{name => "media",attribute => "media_uuid",parent => "Biochemistry",class => "Media",query => "uuid"},
	]
};

$objectDefinitions->{FluxMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'parent',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},#This could get confusing. Make sure the rate is defined relative to the way that the reaction itself is defined (i.e. even if the directionality of the reaction is <= we should define the rate relative to the forward direction, and if it is consistent with the directionality constraint it would be negative)
		{name => 'reacton_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "reaction",attribute => "reacton_uuid",parent => "Biochemistry",class => "Reaction",query => "uuid"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"},
	]
};

$objectDefinitions->{UptakeMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'parent',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"},
	]
};

$objectDefinitions->{MetaboliteMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'parent',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},#In metabolomic experiments it is often hard to measure precisely whether a metabolite is present or not. and (even more so) it’s concentration. However, I imagine it is possible to guess a “probability” of particular compounds being present or not. I wanted to talk to one of the guys at Argonne (The guy who was trying to schedule the workshop for KBase) about metabolomics but we ran out of time. We should consult with a metabolomics expert on what a realistic thing to put into this table would be.
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},#I changed this from “extracellular [0/1]” since we could techincally measure them in any given compartment, not just cytosol vs. extracellular
		{name => 'method',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"},
	]
};

$objectDefinitions->{GeneMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'parent',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},
		{name => 'feature_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'method',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "feature",attribute => "feature_uuid",parent => "Genome",class => "Feature",query => "uuid"},
	]
};

$objectDefinitions->{User} = {
	parents => ["ObjectManager"],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'login',perm => 'rw',type => 'Str',req => 1},
		{name => 'password',perm => 'rw',type => 'Str',req => 1},
		{name => 'email',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'firstname',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'lastname',perm => 'rw',type => 'Str',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Biochemistry} = {
	parents => ["ObjectManager"],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Bool',req => 0,default => "1"},
		{name => 'public',perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
	],
	subobjects => [
		{name => "compartments",class => "Compartment",type => "child"},
		{name => "compounds",class => "Compound",type => "child"},
		{name => "reactions",class => "Reaction",type => "child"},
		{name => "media",class => "Media",type => "child"},
		{name => "compoundSets",class => "CompoundSet",type => "child"},
		{name => "reactionSets",class => "ReactionSet",type => "child"},
		{name => "compoundAliasSets",class => "CompoundAliasSet",type => "child"},
		{name => "reactionAliasSets",class => "ReactionAliasSet",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{CompoundAliasSet} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "compoundAliases",class => "CompoundAlias",type => "hasharray(alias)"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{CompoundAlias} = {
       parents => ['CompoundAliasSet'],
       class => 'encompassed',
       attributes => [
              {name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
              {name => 'alias',perm => 'rw',type => 'Str',req => 1}
       ],
       subobjects => [],
       primarykeys => [ qw(alias compound_uuid) ],
       links => [
              {name => "compound",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"},
       ]
};

$objectDefinitions->{ReactionAliasSet} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "reactionAliases",class => "ReactionAlias",type => "hasharray(alias)"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ReactionAlias} = {
       parents => ['ReactionAliasSet'],
       class => 'encompassed',
       attributes => [
              {name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
              {name => 'alias',perm => 'rw',type => 'Str',req => 1}
       ],
       subobjects => [],
       primarykeys => [ qw(alias reaction_uuid) ],
       links => [
              {name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",class => "Reaction",query => "uuid"},
       ]
};

$objectDefinitions->{Compartment} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 2,req => 1},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Compound} = {
	alias => "Biochemistry",
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'abbreviation',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'cksum',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'unchargedFormula',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'formula',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'mass',perm => 'rw',type => 'Num',req => 0},
		{name => 'defaultCharge',perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaG',perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [
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
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'structure',perm => 'rw',type => 'Str',req => 1},
		{name => 'cksum',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
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
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
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
	alias => "Biochemistry",
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'abbreviation',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'cksum',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'deltaG',perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',perm => 'rw',type => 'Num',req => 0},
		{name => 'reversibility',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'thermoReversibility',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'defaultProtons',perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [
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
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
		{name => 'cofactor',perm => 'rw',type => 'Bool',req => 0,default => "0"},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 0},
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1}
	],
	subobjects => [
		{name => "transports",class => "InstanceTransport",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",class => "Compartment",query => "uuid"}
	]
};

$objectDefinitions->{InstanceTransport} = {
	parents => ['ReactionInstance'],
	class => 'encompassed',
	attributes => [
		{name => 'reactioninstance_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'isDefined',perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'isMinimal',perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
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
		{name => 'media_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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

$objectDefinitions->{CompoundSet} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [
		{name => "compounds",class => "CompoundSetCompound",type => "link",attribute => "compound_uuid",parent => "Biochemistry",class => "Compound",query => "uuid"}
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ReactionSet} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [
		{name => "reactions",class => "ReactionSetReaction",type => "link",attribute => "reaction_uuid",parent => "Biochemistry",class => "Reaction",query => "uuid"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Model} = {
	parents => ['ObjectManager'],
	class => 'parent',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'ModelSEED::varchar',req => 1},
		{name => 'name',perm => 'rw',type => 'Str',len => 32,req => 0,default => ""},
		{name => 'version',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 0,default => "Singlegenome"},
		{name => 'status',perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'reactions',perm => 'rw',type => 'Int',req => 0},
		{name => 'compounds',perm => 'rw',type => 'Int',req => 0},
		{name => 'annotations',perm => 'rw',type => 'Int',req => 0},
		{name => 'growth',perm => 'rw',type => 'Num',req => 0},
		{name => 'current',perm => 'rw',type => 'Int',req => 0,default => "1"},
		{name => 'mapping_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'biochemistry_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'annotation_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
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
	alias => "Model",
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
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
		{name => 'biomass_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'model_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'label',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'model_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'charge',perm => 'rw',type => 'Num',req => 0},
		{name => 'formula',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'model_compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'model_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'protons',perm => 'rw',type => 'Num',req => 0},
		{name => 'model_compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'model_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'model_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 1,default => ""},
		{name => 'type',perm => 'rw',type => 'Str',req => 1},
		{name => 'description',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'model_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'media_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'expressionData_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'regmodel_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'geneko',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'reactionko',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'drainRxn',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'growthConstraint',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'uptakeLimits',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'thermodynamicConstraints',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
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
		{name => 'modelfba_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modelcompound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'modelfba_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modelreaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'modelfba_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'feature_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'mapping_uuid',perm => 'rw',type => 'ModelSEED::uuid'}
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

$objectDefinitions->{Feature} = {
	parents => ['Annotation'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'cksum',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'genome_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'start',perm => 'rw',type => 'Int',req => 0},
		{name => 'stop',perm => 'rw',type => 'Int',req => 0},
		{name => 'contig',perm => 'rw',type => 'Str',req => 0},
		{name => 'direction',perm => 'rw',type => 'Str',req => 0},
		{name => 'sequence',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [
		{name => "featureroles",class => "FeatureRole",type => "encompassed"},
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
		{name => 'feature_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'role_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'biochemistry_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
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

$objectDefinitions->{ComplexAliasSet} = {
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "complexAliases",class => "ComplexAlias",type => "hasharray(alias)"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ComplexAlias} = {
       parents => ['ComplexAliasSet'],
       class => 'encompassed',
       attributes => [
              {name => 'complex_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
              {name => 'alias',perm => 'rw',type => 'Str',req => 1}
       ],
       subobjects => [],
       primarykeys => [ qw(alias complex_uuid) ],
       links => [
              {name => "complex",attribute => "complex_uuid",parent => "Mapping",class => "Complex",query => "uuid"},
       ]
};

$objectDefinitions->{RoleAliasSet} = {
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "roleAliases",class => "RoleAlias",type => "hasharray(alias)"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{RoleAlias} = {
       parents => ['RoleAliasSet'],
       class => 'encompassed',
       attributes => [
              {name => 'role_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
              {name => 'alias',perm => 'rw',type => 'Str',req => 1}
       ],
       subobjects => [],
       primarykeys => [ qw(alias role_uuid) ],
       links => [
              {name => "role",attribute => "role_uuid",parent => "Mapping",class => "Role",query => "uuid"},
       ]
};

$objectDefinitions->{RolesetAliasSet} = {
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "rolesetAliases",class => "RolesetAlias",type => "hasharray(alias)"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{RolesetAlias} = {
       parents => ['RolesetAliasSet'],
       class => 'encompassed',
       attributes => [
              {name => 'roleset_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
              {name => 'alias',perm => 'rw',type => 'Str',req => 1}
       ],
       subobjects => [],
       primarykeys => [ qw(alias roleset_uuid) ],
       links => [
              {name => "roleset",attribute => "roleset_uuid",parent => "Mapping",class => "Roleset",query => "uuid"},
       ]
};

$objectDefinitions->{Role} = {
	alias => "Mapping",
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'seedfeature',perm => 'rw',type => 'Str',len => 36,req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Roleset} = {
	alias => "Mapping",
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'subclass',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
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
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'transprotonNature',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""}
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
		{name => 'reaction_rule_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
	alias => "Mapping",
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""}
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
		{name => 'complex_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'role_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
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
