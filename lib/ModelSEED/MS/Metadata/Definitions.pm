use strict;
package ModelSEED::MS::DB::Definitions;

my $objectDefinitions = {};

$objectDefinitions->{FBAProblem} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'maximize',perm => 'rw',type => 'Bool',req => 0},
		{name => 'milp',perm => 'rw',type => 'Bool',req => 0},
		{name => 'decomposeReversibleFlux',perm => 'rw',type => 'Bool',len => 32,req => 1},
		{name => 'decomposeReversibleDrainFlux',perm => 'rw',type => 'Bool',len => 32,req => 1},
		{name => 'fluxUseVariables',perm => 'rw',type => 'Bool',len => 32,req => 1},
		{name => 'drainfluxUseVariables',perm => 'rw',type => 'Bool',len => 32,req => 1},
	],
	subobjects => [
		{name => "objectiveTerms",class => "ObjectiveTerm",type => "child"},
		{name => "constraints",class => "Constraint",type => "child"},
		{name => "variables",class => "Variable",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ObjectiveTerm} = {
	parents => ['FBAProblem'],
	class => 'child',
	attributes => [
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 0},
		{name => 'variable_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "variable",attribute => "variable_uuid",parent => "FBAProblem",method => "variables"}
	]
};

$objectDefinitions->{Constraint} = {
	parents => ['FBAProblem'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'name',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
		{name => 'rightHandSide',perm => 'rw',type => 'Num',req => 1},
		{name => 'equalityType',perm => 'rw',type => 'Str',len => 1,req => 1},
		{name => 'index',perm => 'rw',type => 'Int',len => 1,req => 1},
		{name => 'primal',perm => 'rw',type => 'Bool',len => 1,req => 1},
		{name => 'entity_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'dualConstraint_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'dualVariable_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
	],
	subobjects => [
		{name => "constraintVariables",class => "ConstraintVariable",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "dualConstraint",attribute => "dualConstraint_uuid",parent => "FBAProblem",method => "constraints"},
		{name => "dualVariable",attribute => "dualVariable_uuid",parent => "FBAProblem",method => "constraints"},
	]
};

$objectDefinitions->{ConstraintVariable} = {
	parents => ['Constraint'],
	class => 'child',
	attributes => [
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 0},
		{name => 'variable_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "variable",attribute => "variable_uuid",parent => "FBAProblem",method => "variables"}
	]
};

$objectDefinitions->{Variable} = {
	parents => ['FBAProblem'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'name',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
		{name => 'binary',perm => 'rw',type => 'Bool',req => 0,default => 0},
		{name => 'start',perm => 'rw',type => 'Num',req => 1,default => 0},
		{name => 'upperBound',perm => 'rw',type => 'Num',req => 1},
		{name => 'lowerBound',perm => 'rw',type => 'Num',req => 1},
		{name => 'min',perm => 'rw',type => 'Num',req => 1},
		{name => 'max',perm => 'rw',type => 'Num',req => 1},
		{name => 'value',perm => 'rw',type => 'Num',req => 1,default => 0},
		{name => 'entity_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'index',perm => 'rw',type => 'Int',req => 1},
		{name => 'primal',perm => 'rw',type => 'Bool',len => 1,req => 1,default => 1},	
		{name => 'dualConstraint_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'upperBoundDualVariable_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'lowerBoundDualVariable_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0}
	],
	subobjects => [
		{name => "constraintVariables",class => "ConstraintVariable",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "dualConstraint",attribute => "dualConstraint_uuid",parent => "FBAProblem",method => "constraints"},
		{name => "upperBoundDualVariable",attribute => "upperBoundDualVariable_uuid",parent => "FBAProblem",method => "constraints"},
		{name => "lowerBoundDualVariable",attribute => "lowerBoundDualVariable_uuid",parent => "FBAProblem",method => "constraints"},
	]
};

$objectDefinitions->{Genome} = {
	parents => ['Annotation'],
	class => 'indexed',
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
	parents => ["ModelSEED::Store"],
	class => 'indexed',
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
		{name => "genome",attribute => "genome_uuid",parent => "ModelSEED::Store",method => "Genome"},
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
		{name => "strain",attribute => "strain_uuid",parent => "Genome",method => "strains"}, # Genome doesn't include any subobjects
		{name => "media",attribute => "media_uuid",parent => "Biochemistry",method => "media"},
	]
};

$objectDefinitions->{FluxMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},#This could get confusing. Make sure the rate is defined relative to the way that the reaction itself is defined (i.e. even if the directionality of the reaction is <= we should define the rate relative to the forward direction, and if it is consistent with the directionality constraint it would be negative)
		{name => 'reacton_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "reaction",attribute => "reacton_uuid",parent => "Biochemistry",method => "reactions"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method => "compartments"},
	]
};

$objectDefinitions->{UptakeMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"},
	]
};

$objectDefinitions->{MetaboliteMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},#In metabolomic experiments it is often hard to measure precisely whether a metabolite is present or not. and (even more so) it’s concentration. However, I imagine it is possible to guess a “probability” of particular compounds being present or not. I wanted to talk to one of the guys at Argonne (The guy who was trying to schedule the workshop for KBase) about metabolomics but we ran out of time. We should consult with a metabolomics expert on what a realistic thing to put into this table would be.
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},#I changed this from “extracellular [0/1]” since we could techincally measure them in any given compartment, not just cytosol vs. extracellular
		{name => 'method',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method => "compartments"},
	]
};

$objectDefinitions->{GeneMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',perm => 'rw',type => 'Str',req => 0},
		{name => 'feature_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'method',perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "feature",attribute => "feature_uuid",parent => "Genome",method => "features"}, # Genome doesn't include any subobjects
	]
};

$objectDefinitions->{User} = {
    parents => ["ModelSEED::Store"],
    class => 'child',
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
	parents => ["ModelSEED::Store"],
	class => 'indexed',
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
		{name => "reactioninstances",class => "ReactionInstance",type => "child"},
		{name => "media",class => "Media",type => "child"},
		{name => "compoundSets",class => "CompoundSet",type => "child"},
		{name => "reactionSets",class => "ReactionSet",type => "child"},
		{name => "compoundAliasSets",class => "CompoundAliasSet",type => "child"},
		{name => "reactionAliasSets",class => "ReactionAliasSet",type => "child"},
		{name => "reactioninstanceAliasSets",class => "ReactionInstanceAliasSet",type => "child"},
		{name => "cues",class => "Cue",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{CompoundAliasSet} = {
	parents => ['Biochemistry'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "compoundAliases",class => "CompoundAlias",type => "child"},
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
              {name => "compound",attribute => "compound_uuid",parent => "Biochemistry",methods => "compounds"},
       ]
};

$objectDefinitions->{ReactionAliasSet} = {
	parents => ['Biochemistry'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "reactionAliases",class => "ReactionAlias",type => "child"},
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
              {name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method => "reactions"},
       ]
};

$objectDefinitions->{ReactionInstanceAliasSet} = {
	parents => ['Biochemistry'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "reactioninstanceAliases",class => "ReactionInstanceAlias",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ReactionInstanceAlias} = {
       parents => ['ReactionInstanceAliasSet'],
       class => 'encompassed',
       attributes => [
              {name => 'reactioninstance_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
              {name => 'alias',perm => 'rw',type => 'Str',req => 1}
       ],
       subobjects => [],
       primarykeys => [ qw(alias reactioninstance_uuid) ],
       links => [
              {name => "reactioninstance",attribute => "reactioninstance_uuid",parent => "Biochemistry",method => "reactioninstances"},
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
		{name => 'hierarchy',perm => 'rw',type => 'Int',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{Cue} = {
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
		{name => 'smallMolecule',perm => 'rw',type => 'Bool',req => 0},
		{name => 'priority',perm => 'rw',type => 'Int',req => 0},
	],
	subobjects => [
		{name => "structures",class => "CompoundStructure",type => "encompassed"},
		{name => "pks",class => "CompoundPk",type => "encompassed"},
	],
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
		{name => "compoundCues",class => "CompoundCue",type => "encompassed"},
		{name => "structures",class => "CompoundStructure",type => "encompassed"},
		{name => "pks",class => "CompoundPk",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{CompoundCue} = {
	parents => ['Compound'],
	class => 'encompassed',
	attributes => [
		{name => 'cue_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'count',perm => 'rw',type => 'Int',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(type cksum compound_uuid) ],
	links => [
		{name => "cue",attribute => "cue_uuid",parent => "Biochemistry",method => "cues"}
	]
};

$objectDefinitions->{CompoundStructure} = {
	parents => ['Compound'],
	class => 'encompassed',
	attributes => [
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
		{name => 'status',perm => 'rw',type => 'Str',req => 0}
	],
	subobjects => [
		{name => "reactionCues",class => "ReactionCue",type => "encompassed"},
		{name => "reactionreactioninstances",class => "ReactionReactionInstance",type => "encompassed"},
		{name => "reagents",class => "Reagent",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ReactionReactionInstance} = {
	parents => ['Reaction'],
	class => 'encompassed',
	attributes => [
		{name => 'reactioninstance_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "reactioninstance",attribute => "reactioninstance_uuid",parent => "Biochemistry",method => "reactioninstances"}
	]
};

$objectDefinitions->{ReactionCue} = {
	parents => ['Reaction'],
	class => 'encompassed',
	attributes => [
		{name => 'cue_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'count',perm => 'rw',type => 'Num',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw() ],
	links => [
		{name => "cue",attribute => "cue_uuid",parent => "Biochemistry",method => "cues"}
	]
};

$objectDefinitions->{Reagent} = {
	parents => ['Reaction'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
		{name => 'cofactor',perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1,default => "0"},#0 for not transported,>0 for transported
	],
	subobjects => [],
	primarykeys => [ qw(reaction_uuid compound_uuid compartmentIndex) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"}
	]
};

$objectDefinitions->{ReactionInstance} = {
	alias => "Biochemistry",
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'sourceEquation',perm => 'rw',type => 'Str',len => 36,req => 1},
		{name => 'transprotonNature',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""}
	],
	subobjects => [
		{name => "transports",class => "InstanceTransport",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method => "compartments"},
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method => "reactions"}
	]
};

$objectDefinitions->{InstanceTransport} = {
	parents => ['ReactionInstance'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(compound_uuid reactiondefault_uuid compartmentIndex) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method => "compartments"}
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
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'concentration',perm => 'rw',type => 'Num',req => 0,default => "0.001"},
		{name => 'maxFlux',perm => 'rw',type => 'Num',req => 0,default => "100"},
		{name => 'minFlux',perm => 'rw',type => 'Num',req => 0,default => "-100"},
	],
	subobjects => [],
	primarykeys => [ qw(media_uuid compound_uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"},
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
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [
		{name => "compounds",class => "CompoundSetCompound",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{CompoundSetCompound} = {
	parents => ['CompoundSet'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"}
	]
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
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [
		{name => "reactions",class => "ReactionSetReaction",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ReactionSetReaction} = {
	parents => ['ReactionSet'],
	class => 'encompassed',
	attributes => [
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method => "reactions"}
	]
};

$objectDefinitions->{Model} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
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
		{name => "biochemistry",attribute => "biochemistry_uuid",parent => "ModelSEED::Store",method => "Biochemistry"},
		{name => "mapping",attribute => "mapping_uuid",parent => "ModelSEED::Store",method => "Mapping"},
		{name => "annotation",attribute => "annotation_uuid",parent => "ModelSEED::Store",method => "Annotation"},
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
		{name => 'dna',perm => 'rw',type => 'Num',req => 0,default => "0.05"},
		{name => 'rna',perm => 'rw',type => 'Num',req => 0,default => "0.1"},
		{name => 'protein',perm => 'rw',type => 'Num',req => 0,default => "0.5"},
		{name => 'cellwall',perm => 'rw',type => 'Num',req => 0,default => "0.15"},
		{name => 'lipid',perm => 'rw',type => 'Num',req => 0,default => "0.05"},
		{name => 'cofactor',perm => 'rw',type => 'Num',req => 0,default => "0.15"}
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
		{name => 'modelcompound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(biomass_uuid modelcompound_uuid) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",method => "modelcompounds"},
	]
};

$objectDefinitions->{ModelCompartment} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'compartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartmentIndex',perm => 'rw',type => 'Int',req => 1},
		{name => 'label',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'pH',perm => 'rw',type => 'Num',req => 0,default => "7"},
		{name => 'potential',perm => 'rw',type => 'Num',req => 0,default => "0"},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method => "modelcompartments"}
	]
};

$objectDefinitions->{ModelCompound} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'compound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'charge',perm => 'rw',type => 'Num',req => 0},
		{name => 'formula',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'modelcompartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(model_uuid uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"},
		{name => "modelcompartment",attribute => "modelcompartment_uuid",parent => "Model",method => "modelcompartments"}
	]
};

$objectDefinitions->{ModelReaction} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'direction',perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'protons',perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'modelcompartment_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [
		{name => "gpr",class => "ModelReactionRawGPR",type => "encompassed"},
		{name => "modelReactionReagents",class => "ModelReactionReagent",type => "encompassed"},
	],
	primarykeys => [ qw(model_uuid uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method => "reactions"},
		{name => "modelcompartment",attribute => "modelcompartment_uuid",parent => "Model",method => "modelcompartments"}
	]
};

$objectDefinitions->{ModelReactionReagent} = {
	parents => ['ModelReaction'],
	class => 'encompassed',
	attributes => [
		{name => 'modelcompound_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(modelcompound_uuid) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",method => "modelcompounds"}
	]
};

$objectDefinitions->{ModelReactionRawGPR} = {
	parents => ['ModelReaction'],
	class => 'encompassed',
	attributes => [
		{name => 'isCustomGPR',perm => 'rw',type => 'Int',req => 0,default => "1"},
		{name => 'rawGPR',perm => 'rw',type => 'Str',req => 0,default => "UNKNOWN"},
	],
	subobjects => [],
	primarykeys => [ qw(model_uuid modelreaction_uuid) ],
	links => []
};

$objectDefinitions->{FBAFormulation} = {
	parents => ['model_uuid','Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 1,default => ""},
		{name => 'model_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'regulatorymodel_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'media_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'type',perm => 'rw',type => 'Str',req => 1},
		{name => 'description',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'expressionData_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'growthConstraint',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "none"},
		{name => 'thermodynamicConstraints',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "none"},
		{name => 'allReversible',perm => 'rw',type => 'Int',len => 255,req => 0,default => "0"},
		{name => 'uptakeLimits',perm => 'rw',type => 'HashRef',req => 0,default => "sub{return {};}"},
		{name => 'numberOfSolutions',perm => 'rw',type => 'Int',req => 1,default => "1"},
		{name => 'geneKO',perm => 'rw',type => 'ArrayRef',req => 1,default => "sub{return [];}"},
		{name => 'defaultMaxFlux',perm => 'rw',type => 'Int',req => 1,default => 1000},
		{name => 'defaultMaxDrainFlux',perm => 'rw',type => 'Int',req => 1,default => 1000},
		{name => 'defaultMinDrainFlux',perm => 'rw',type => 'Int',req => 1,default => -1000},
	],
	subobjects => [
		{name => "fbaObjectiveTerms",class => "FBAObjectiveTerm",type => "encompassed"},
		{name => "fbaCompoundConstraints",class => "FBACompoundConstraint",type => "encompassed"},
		{name => "fbaReactionConstraints",class => "FBAReactionConstraint",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "media",attribute => "media_uuid",parent => "Biochemistry",method => "media"}
	]
};

$objectDefinitions->{FBACompoundConstraint} = {
	parents => ['fbaformulation_uuid','FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'modelcompound_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 1,req => 0},
		{name => 'variableType',perm => 'rw',type => 'Str',req => 1},
		{name => 'max',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'min',perm => 'rw',type => 'Num',req => 0,default => "0"}
	],
	subobjects => [],
	primarykeys => [ qw(atom) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",method => "modelcompounds"}
	]
};

$objectDefinitions->{FBAReactionConstraint} = {
	parents => ['fbaformulation_uuid','FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'reaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 1,req => 0},
		{name => 'variableType',perm => 'rw',type => 'Str',req => 1},
		{name => 'max',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'min',perm => 'rw',type => 'Num',req => 0,default => "0"}
	],
	subobjects => [],
	primarykeys => [ qw(atom) ],
	links => [
		{name => "modelreaction",attribute => "modelreaction_uuid",parent => "Model",method => "modelreactions"}
	]
};

$objectDefinitions->{FBAObjectiveTerm} = {
	parents => ['fbaformulation_uuid','FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'coefficient',perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'variableType',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'variable_uuid',perm => 'rw',type => 'ModelSEED::uuid',len => 1,req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(atom) ],
	links => []
};

$objectDefinitions->{FBAResults} = {
	parents => ['model_uuid','Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 1,default => ""},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'fbaformulation_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'resultNotes',perm => 'rw',type => 'Str',req => 1,default => ""},
		{name => 'objectiveValue',perm => 'rw',type => 'Num',req => 1,default => ""},
	],
	subobjects => [
		{name => "fbaCompoundVariables",class => "FBACompoundVariable",type => "encompassed"},
		{name => "fbaReactionVariables",class => "FBAReactionVariable",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "fbaformulation",attribute => "fbaformulation_uuid",parent => "Model",method => "fbaformulations"} # model does not contain a subobject for FBAFormulations
	]
};

$objectDefinitions->{FBACompoundVariable} = {
	parents => ['FBAResults'],
	class => 'encompassed',
	attributes => [
		{name => 'modelcompound_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'variableType',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'lowerBound',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'upperBound',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'min',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'max',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'value',perm => 'rw',type => 'Str',len => 1,req => 0},
	],
        subobjects => [],
	primarykeys => [ qw(modelfba_uuid modelcompound_uuid) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",method => "modelcompounds"},
	]
};

$objectDefinitions->{FBAReactionVariable} = {
	parents => ['FBAResults'],
	class => 'encompassed',
	attributes => [
		{name => 'modelreaction_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'variableType',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'lowerBound',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'upperBound',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'min',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'max',perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'value',perm => 'rw',type => 'Str',len => 1,req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(modelfba_uuid modelcompound_uuid) ],
	links => [
		{name => "modelreaction",attribute => "modelreaction_uuid",parent => "Model",method => "modelreactions"},
	]
};

$objectDefinitions->{Annotation} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'mapping_uuid',perm => 'rw',type => 'ModelSEED::uuid'}
	],
	subobjects => [
		{name => "genomes",class => "Genome",type => "child"},
		{name => "features",class => "Feature",type => "child"},
		{name => "subsystemStates",class => "SubsystemState",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "mapping",attribute => "mapping_uuid",parent => "ModelSEED::Store",method => "Mapping"},
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
		{name => "genome",attribute => "genome_uuid",parent => "Annotation",method => "genomes"},
	]
};

$objectDefinitions->{SubsystemState} = {
	parents => ['Annotation'],
	class => 'child',
	attributes => [
		{name => 'roleset_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'name',perm => 'rw',type => 'Str',req => 0},
		{name => 'variant',perm => 'rw',type => 'Str',req => 0,default => ""}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{FeatureRole} = {
	parents => ['Feature'],
	class => 'encompassed',
	attributes => [
		{name => 'role_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartment',perm => 'rw',type => 'Str',default => "unknown"},
		{name => 'comment',perm => 'rw',type => 'Str',default => ""},
		{name => 'delimiter',perm => 'rw',type => 'Str',default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(annotation_uuid feature_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",method => "roles"},
	]
};

$objectDefinitions->{Mapping} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'biochemistry_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
	],
	subobjects => [
		{name => "universalReactions",class => "UniversalReaction",type => "child"},
		{name => "biomassTemplates",class => "BiomassTemplate",type => "child"},
		{name => "roles",class => "Role",type => "child"},
		{name => "rolesets",class => "RoleSet",type => "child"},
		{name => "complexes",class => "Complex",type => "child"},
		{name => "roleSetAliasSets",class => "RoleSetAliasSet",type => "child"},
		{name => "roleAliasSets",class => "RoleAliasSet",type => "child"},
		{name => "complexAliasSets",class => "ComplexAliasSet",type => "child"}
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "biochemistry",attribute => "biochemistry_uuid",parent => "ModelSEED::Store",method => "Biochemistry"},
	]
};

$objectDefinitions->{UniversalReaction} = {
	parents => ['Mapping'],
	class => 'encompassed',
	attributes => [
		{name => 'type',perm => 'rw',type => 'Str',req => 1},
		{name => 'reactioninstance_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "reactioninstance",attribute => "reactioninstance_uuid",parent => "Biochemistry",method => "reactioninstances"},
	]
};

$objectDefinitions->{BiomassTemplate} = {
	parents => ['Mapping'],
	class => 'encompassed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'dna',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'rna',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'protein',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'lipid',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'cellwall',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'cofactor',perm => 'rw',type => 'Num',req => 0,default => "0"}
	],
	subobjects => [
		{name => "biomassTemplateComponents",class => "BiomassTemplateComponent",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{BiomassTemplateComponent} = {
	parents => ['BiomassTemplate'],
	class => 'encompassed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'class',perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'compound_uuid',perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'coefficientType',perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'coefficient',perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'condition',perm => 'rw',type => 'Str',req => 0,default => "0"},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method => "compounds"},
	]
};

$objectDefinitions->{ComplexAliasSet} = {
	parents => ['Mapping'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "complexAliases",class => "ComplexAlias",type => "child"},
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
              {name => "complex",attribute => "complex_uuid",parent => "Mapping",method => "complexes"},
       ]
};

$objectDefinitions->{RoleAliasSet} = {
	parents => ['Mapping'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "roleAliases",class => "RoleAlias",type => "child"},
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
              {name => "role",attribute => "role_uuid",parent => "Mapping",method => "roles"},
       ]
};

$objectDefinitions->{RoleSetAliasSet} = {
	parents => ['Mapping'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'type',perm => 'rw',type => 'Str',req => 0,default => "0"}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',perm => 'rw',type => 'Str',req => 0,default => "0"} #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [
		{name => "roleSetAliases",class => "RoleSetAlias",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{RoleSetAlias} = {
       parents => ['RoleSetAliasSet'],
       class => 'encompassed',
       attributes => [
              {name => 'roleset_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
              {name => 'alias',perm => 'rw',type => 'Str',req => 1}
       ],
       subobjects => [],
       primarykeys => [ qw(alias roleset_uuid) ],
       links => [
              {name => "roleset",attribute => "roleset_uuid",parent => "Mapping",method => "rolesets"},
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
		{name => 'seedfeature',perm => 'rw',type => 'Str',len => 36,req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{RoleSet} = {
	alias => "Mapping",
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'class',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'subclass',perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',perm => 'rw',type => 'Str',len => 32,req => 1}
	],
	subobjects => [
		{name => "rolesroles",class => "RoleSetRole",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{RoleSetRole} = {
	parents => ['RoleSet'],
	class => 'encompassed',
	attributes => [
		{name => 'role_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",method => "roles"}
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
		{name => 'compartment',perm => 'rw',type => 'Str',req => 0,default => "cytosol"},
	],
	subobjects => [
		{name => "complexreactioninstances",class => "ComplexReactionInstance",type => "encompassed"},
		{name => "complexroles",class => "ComplexRole",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => []
};

$objectDefinitions->{ComplexRole} = {
	parents => ['Complex'],
	class => 'encompassed',
	attributes => [
		{name => 'role_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'optional',perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'type',perm => 'rw',type => 'Str',len => 1,req => 0,default => "G"},
		{name => 'triggering',perm => 'rw',type => 'Int',len => 1,req => 0,default => "1"}
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",method => "roles"}
	]
};

$objectDefinitions->{ComplexReactionInstance} = {
	parents => ['Complex'],
	class => 'encompassed',
	attributes => [
		{name => 'reactioninstance_uuid',perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "reactioninstance",attribute => "reactioninstance_uuid",parent => "Biochemistry",method => "reactioninstances"}
	]
};

sub objectDefinitions {
	return $objectDefinitions;
}

1;
