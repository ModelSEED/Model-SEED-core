use strict;
package ModelSEED::MS::Metadata::Definitions;

my $objectDefinitions = {};

$objectDefinitions->{FBAFormulation} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'regulatorymodel_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'media_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'fva',printOrder => 0,perm => 'rw',type => 'Bool',default => 0},
		{name => 'comboDeletions',printOrder => 0,perm => 'rw',type => 'Int',default => 0},
		{name => 'fluxMinimization',printOrder => 0,perm => 'rw',type => 'Bool',default => 0},
		{name => 'findMinimalMedia',printOrder => 0,perm => 'rw',type => 'Bool',default => 0},
		{name => 'notes',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'expressionData_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'objectiveConstraintFraction',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "none"},
		{name => 'allReversible',printOrder => 0,perm => 'rw',type => 'Int',len => 255,req => 0,default => "0"},
		{name => 'defaultMaxFlux',printOrder => 0,perm => 'rw',type => 'Int',req => 1,default => 1000},
		{name => 'defaultMaxDrainFlux',printOrder => 0,perm => 'rw',type => 'Int',req => 1,default => 1000},
		{name => 'defaultMinDrainFlux',printOrder => 0,perm => 'rw',type => 'Int',req => 1,default => -1000},
		{name => 'maximizeObjective',printOrder => 0,perm => 'rw',type => 'Bool',req => 1,default => 1},		
		{name => 'decomposeReversibleFlux',printOrder => 0,perm => 'rw',type => 'Bool',len => 32,req => 0,default => 0},
		{name => 'decomposeReversibleDrainFlux',printOrder => 0,perm => 'rw',type => 'Bool',len => 32,req => 0,default => 0},
		{name => 'fluxUseVariables',printOrder => 0,perm => 'rw',type => 'Bool',len => 32,req => 0,default => 0},
		{name => 'drainfluxUseVariables',printOrder => 0,perm => 'rw',type => 'Bool',len => 32,req => 0,default => 0},
		{name => 'geneKO_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'reactionKO_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'parameters',printOrder => 0,perm => 'rw',type => 'HashRef',req => 0,default => "sub{return {};}"},
		{name => 'uptakeLimits',printOrder => 0,perm => 'rw',type => 'HashRef',req => 0,default => "sub{return {};}"},
		{name => 'numberOfSolutions',printOrder => 0,perm => 'rw',type => 'Int',req => 0,default => 1},
		{name => 'simpleThermoConstraints',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => 1},
		{name => 'thermodynamicConstraints',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => 1},
		{name => 'noErrorThermodynamicConstraints',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => 1},
		{name => 'minimizeErrorThermodynamicConstraints',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => 1},
	],
	subobjects => [
		{name => "fbaObjectiveTerms",class => "FBAObjectiveTerm",type => "encompassed"},
		{name => "fbaConstraints",class => "FBAConstraint",type => "encompassed"},
		{name => "fbaReactionBounds",class => "FBAReactionBound",type => "encompassed"},
		{name => "fbaCompoundBounds",class => "FBACompoundBound",type => "encompassed"},
		{name => "fbaResults",class => "FBAResult",type => "encompassed"},
		{name => "fbaPhenotypeSimulations",class => "FBAPhenotypeSimulation",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "media",attribute => "media_uuid",parent => "Biochemistry",method=>"media"},
		{name => "geneKOs",attribute => "geneKO_uuids",parent => "Annotation",method=>"features",array => 1},
		{name => "reactionKOs",attribute => "reactionKO_uuids",parent => "Biochemistry",method=>"reactions",array => 1},
	],
    reference_id_types => [ qw(uuid) ],
};
	
$objectDefinitions->{FBAConstraint} = {
	parents => ['FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'name',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'rhs',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'sign',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "0"}
	],
	subobjects => [
		{name => "fbaConstraintVariables",class => "FBAConstraintVariable",type => "encompassed"},
	],
	primarykeys => [ qw(atom) ],
	links => []
};

$objectDefinitions->{FBAConstraintVariable} = {
	parents => ['FBAConstraint'],
	class => 'encompassed',
	attributes => [
		{name => 'entity_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 1,req => 0},
		{name => 'entityType',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'variableType',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',len => 1,req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(atom) ],
	links => []
};

$objectDefinitions->{FBAReactionBound} = {
	parents => ['FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'modelreaction_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'variableType',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'upperBound',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
		{name => 'lowerBound',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(reaction_uuid variableType) ],
	links => []
};

$objectDefinitions->{FBACompoundBound} = {
	parents => ['FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'modelcompound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'variableType',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'upperBound',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
		{name => 'lowerBound',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(reaction_uuid variableType) ],
	links => []
};

$objectDefinitions->{FBAPhenotypeSimulation} = {
	parents => ['FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'label',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'geneKO',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 1,default => "sub{return [];}"},
		{name => 'reactionKO',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 1,default => "sub{return [];}"},
		{name => 'media_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'observedGrowthFraction',printOrder => 0,perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(reaction_uuid variableType) ],
	links => [
		{name => "media",attribute => "media_uuid",parent => "Biochemistry",method=>"media"}
	]
};

$objectDefinitions->{FBAObjectiveTerm} = {
	parents => ['FBAFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'entity_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 1,req => 0},
		{name => 'entityType',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'variableType',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',len => 1,req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(atom) ],
	links => []
};

$objectDefinitions->{FBAResult} = {
	parents => ['FBAFormulation'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'notes',printOrder => 3,perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'objectiveValue',printOrder => 2,perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [
		{name => "fbaCompoundVariables",printOrder => 2,class => "FBACompoundVariable",type => "encompassed"},
		{name => "fbaReactionVariables",printOrder => 1,class => "FBAReactionVariable",type => "encompassed"},
		{name => "fbaBiomassVariables",printOrder => 0,class => "FBABiomassVariable",type => "encompassed"},
		{name => "fbaPhenotypeSimultationResults",printOrder => 0,class => "FBAPhenotypeSimultationResult",type => "encompassed"},
		{name => "fbaDeletionResults",printOrder => 0,class => "FBADeletionResult",type => "encompassed"},
		{name => "minimalMediaResults",printOrder => 0,class => "FBAMinimalMediaResult",type => "encompassed"},
		{name => "fbaMetaboliteProductionResults",printOrder => 0,class => "FBAMetaboliteProductionResult",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{FBACompoundVariable} = {
	parents => ['FBAResult'],
	class => 'encompassed',
	attributes => [
		{name => 'modelcompound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'variableType',printOrder => 3,perm => 'rw',type => 'Str',req => 0},
		{name => 'class',printOrder => 3,perm => 'rw',type => 'Str',req => 0},
		{name => 'lowerBound',printOrder => 7,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'upperBound',printOrder => 8,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'min',printOrder => 5,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'max',printOrder => 6,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'value',printOrder => 4,perm => 'rw',type => 'Num',len => 1,req => 0},
	],	
	subobjects => [],
	primarykeys => [ qw() ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",method=>"modelcompounds"},
	]
};

$objectDefinitions->{FBABiomassVariable} = {
	parents => ['FBAResult'],
	class => 'encompassed',
	attributes => [
		{name => 'biomass_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'variableType',printOrder => 2,perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'class',printOrder => 3,perm => 'rw',type => 'Str',req => 0},
		{name => 'lowerBound',printOrder => 6,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'upperBound',printOrder => 7,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'min',printOrder => 4,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'max',printOrder => 5,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'value',printOrder => 3,perm => 'rw',type => 'Num',len => 1,req => 0},
	],	
	subobjects => [],
	primarykeys => [ qw() ],
	links => [
		{name => "biomass",attribute => "biomass_uuid",parent => "Model",method=>"biomasses"},
	]
};

$objectDefinitions->{FBAReactionVariable} = {
	parents => ['FBAResult'],
	class => 'encompassed',
	attributes => [
		{name => 'modelreaction_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'variableType',printOrder => 3,perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'class',printOrder => 3,perm => 'rw',type => 'Str',req => 0},
		{name => 'lowerBound',printOrder => 7,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'upperBound',printOrder => 8,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'min',printOrder => 5,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'max',printOrder => 6,perm => 'rw',type => 'Num',len => 1,req => 0},
		{name => 'value',printOrder => 4,perm => 'rw',type => 'Num',len => 1,req => 0},
	],	
	subobjects => [],
	primarykeys => [ qw(modelfba_uuid modelcompound_uuid) ],
	links => [
		{name => "modelreaction",attribute => "modelreaction_uuid",parent => "Model",method=>"modelreactions"},
	]
};

$objectDefinitions->{FBAPhenotypeSimultationResult} = {
	parents => ['FBAResult'],
	class => 'encompassed',
	attributes => [
		{name => 'simulatedGrowthFraction',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
		{name => 'simulatedGrowth',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
		{name => 'class',printOrder => 3,perm => 'rw',type => 'Str',len => 1,req => 1},
		{name => 'noGrowthCompounds',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'dependantReactions',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'dependantGenes',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'fluxes',printOrder => 0,perm => 'rw',type => 'HashRef',req => 0,default => "sub{return {};}"},
		{name => 'fbaPhenotypeSimulation_uuid',printOrder => 4,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],	
	subobjects => [],
	primarykeys => [ qw(fbaPhenotypeSimulation_uuid) ],
	links => [
		{name => "fbaPhenotypeSimulation",attribute => "fbaPhenotypeSimulation_uuid",parent => "FBAFormulation",method=>"fbaPhenotypeSimulations"},
	]
};

$objectDefinitions->{FBADeletionResult} = {
	parents => ['FBAResult'],
	class => 'encompassed',
	attributes => [
		{name => 'geneko_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 1},
		{name => 'growthFraction',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
	],	
	subobjects => [],
	primarykeys => [ qw(geneko_uuids) ],
	links => [
		{name => "genekos",attribute => "geneko_uuids",parent => "Annotation",method=>"features",array => 1},
	]
};

$objectDefinitions->{FBAMinimalMediaResult} = {
	parents => ['FBAResult'],
	class => 'encompassed',
	attributes => [
		{name => 'minimalMedia_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'essentialNutrient_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 1},
		{name => 'optionalNutrient_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 1},
	],	
	subobjects => [],
	primarykeys => [ qw(minimalMedia_uuid) ],
	links => [
		{name => "minimalMedia",attribute => "minimalMedia_uuid",parent => "Biochemistry",method=>"media"},
		{name => "essentialNutrients",attribute => "essentialNutrient_uuids",parent => "Biochemistry",method=>"compounds",array => 1},
		{name => "optionalNutrients",attribute => "optionalNutrient_uuids",parent => "Biochemistry",method=>"compounds",array => 1}
	]
};

$objectDefinitions->{FBAMetaboliteProductionResult} = {
	parents => ['FBAResult'],
	class => 'encompassed',
	attributes => [
		{name => 'modelCompound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'maximumProduction',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
	],	
	subobjects => [],
	primarykeys => [ qw(minimalMedia_uuid) ],
	links => [
		{name => "modelCompound",attribute => "modelCompound_uuid",parent => "Model",method=>"modelcompounds"},
	]
};

$objectDefinitions->{GapfillingFormulation} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'fbaFormulation_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'balancedReactionsOnly',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => "1"},
		{name => 'guaranteedReaction_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'blacklistedReaction_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'allowableCompartment_uuids',printOrder => 0,perm => 'rw',type => 'ArrayRef',req => 0,default => "sub{return [];}"},
		{name => 'reactionActivationBonus',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'drainFluxMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'directionalityMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'deltaGMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'noStructureMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'noDeltaGMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'biomassTransporterMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'singleTransporterMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'transporterMultiplier',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [
		{name => "gapfillingGeneCandidates",class => "GapfillingGeneCandidate",type => "encompassed"},
		{name => "reactionSetMultipliers",class => "ReactionSetMultiplier",type => "encompassed"},
		{name => "gapfillingSolutions",class => "GapfillingSolution",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "fbaFormulation",attribute => "fbaFormulation_uuid",parent => "Model",method=>"fbaFormulations"},
		{name => "guaranteedReactions",attribute => "guaranteedReaction_uuids",parent => "Biochemistry",method=>"reactions",array => 1},
		{name => "blacklistedReactions",attribute => "blacklistedReaction_uuids",parent => "Biochemistry",method=>"reactions",array => 1},
		{name => "allowableCompartments",attribute => "allowableCompartment_uuids",parent => "Biochemistry",method=>"compartments",array => 1}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{GapfillingGeneCandidate} = {
	parents => ['GapfillingFormulation'],
	class => 'encompassed',
	attributes => [
		{name => 'feature_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'ortholog_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'orthologGenome_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'similarityScore',printOrder => -1,perm => 'rw',type => 'Num',req => 0},
		{name => 'distanceScore',printOrder => -1,perm => 'rw',type => 'Num',req => 0},
		{name => 'role_uuid',printOrder => -1,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "feature",attribute => "feature_uuid",parent => "Annotation",method=>"features"},
		{name => "ortholog",attribute => "ortholog_uuid",parent => "Annotation",method=>"features"},
		{name => "orthologGenome",attribute => "orthogenome_uuid",parent => "Annotation",method=>"genomes"},
		{name => "role",attribute => "role_uuid",parent => "Mapping",method=>"roles"}
	]
};

$objectDefinitions->{ReactionSetMultiplier} = {
	parents => ['GapfillingFormulation'],
	class => 'indexed',
	attributes => [
		{name => 'reactionset_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'reactionsetType',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'multiplierType',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'description',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'multiplier',printOrder => -1,perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "reactionset",attribute => "reactionset_uuid",parent => "Biochemistry",method=>"reactionsets"}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{GapfillingSolution} = {
	parents => ['GapfillingFormulation'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'solutionCost',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "1"},
	],
	subobjects => [
		{name => "gapfillingSolutionReactions",class => "GapfillingSolutionReaction",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{GapfillingSolutionReaction} = {
	parents => ['GapfillingSolution'],
	class => 'child',
	attributes => [
		{name => 'modelreaction_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'direction',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "1"},
	],
	subobjects => [
		{name => "gfSolutionReactionGeneCandidates",class => "GfSolutionReactionGeneCandidate",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "modelreaction",attribute => "modelreaction_uuid",parent => "Model",method=>"modelreactions"},
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{GfSolutionReactionGeneCandidate} = {
	parents => ['GapfillingSolutionReaction'],
	class => 'child',
	attributes => [
		{name => 'feature_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "feature",attribute => "feature_uuid",parent => "Annotation",method=>"features"},
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{FBAProblem} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'maximize',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => 1},
		{name => 'milp',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => 0},
	],
	subobjects => [
		{name => "objectiveTerms",class => "ObjectiveTerm",type => "child"},
		{name => "constraints",class => "Constraint",type => "child"},
		{name => "variables",class => "Variable",type => "child"},
		{name => "solutions",class => "Solution",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
    version => 1.0,
};

$objectDefinitions->{ObjectiveTerm} = {
	parents => ['FBAProblem'],
	class => 'child',
	attributes => [
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',req => 0},
		{name => 'variable_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "variable",attribute => "variable_uuid",parent => "FBAProblem",method=>"variables"}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Constraint} = {
	parents => ['FBAProblem'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'name',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'rightHandSide',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'equalityType',printOrder => 0,perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'index',printOrder => 0,perm => 'rw',type => 'Int',len => 1,req => 0,default => -1},
		{name => 'primal',printOrder => 0,perm => 'rw',type => 'Bool',len => 1,req => 0,default => 1},
		{name => 'entity_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'dualConstraint_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'dualVariable_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
	],
	subobjects => [
		{name => "constraintVariables",class => "ConstraintVariable",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "dualConstraint",attribute => "dualConstraint_uuid",parent => "FBAProblem",method=>"constraints"},
		{name => "dualVariable",attribute => "dualVariable_uuid",parent => "FBAProblem",method=>"variables"},
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{ConstraintVariable} = {
	parents => ['Constraint'],
	class => 'child',
	attributes => [
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',req => 0},
		{name => 'variable_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "variable",attribute => "variable_uuid",parent => "FBAProblem",method=>"variables"}
	],
    reference_id_types => [ qw(uuid) ],
};
	
$objectDefinitions->{Variable} = {
	parents => ['FBAProblem'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'name',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'binary',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => 0},
		{name => 'start',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'upperBound',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'lowerBound',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'entity_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'index',printOrder => 0,perm => 'rw',type => 'Int',req => 0,default => -1},
		{name => 'primal',printOrder => 0,perm => 'rw',type => 'Bool',len => 1,req => 0,default => 1},	
		{name => 'dualConstraint_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'upperBoundDualVariable_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'lowerBoundDualVariable_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "dualConstraint",attribute => "dualConstraint_uuid",parent => "FBAProblem",method=>"constraints"},
		{name => "upperBoundDualVariable",attribute => "upperBoundDualVariable_uuid",parent => "FBAProblem",method=>"variables"},
		{name => "lowerBoundDualVariable",attribute => "lowerBoundDualVariable_uuid",parent => "FBAProblem",method=>"variables"},
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Solution} = {
	parents => ['FBAProblem'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'status',printOrder => 1,perm => 'rw',type => 'Str',req => 0},
		{name => 'method',printOrder => 2,perm => 'rw',type => 'Str',req => 0},
		{name => 'feasible',printOrder => 3,perm => 'rw',type => 'Bool',req => 0},
		{name => 'objective',printOrder => 4,perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [
		{name => "solutionconstraints",printOrder => 0,class => "SolutionConstraint",type => "child"},
		{name => "solutionvariables",printOrder => 1,class => "SolutionVariable",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{SolutionConstraint} = {
	parents => ['Solution'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => -1,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'constraint_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'slack',printOrder => 1,perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "constraint",attribute => "constraint_uuid",parent => "FBAProblem",method=>"constraints"}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{SolutionVariable} = {
	parents => ['Solution'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => -1,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'variable_uuid',printOrder => -1,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'value',printOrder => 2,perm => 'rw',type => 'Num',req => 0},
		{name => 'min',printOrder => 3,perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'max',printOrder => 4,perm => 'rw',type => 'Num',req => 0,default => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "variable",attribute => "variable_uuid",parent => "FBAProblem",method=>"variables"}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Genome} = {
	parents => ['Annotation'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'id',printOrder => 1,perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',printOrder => 2,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'source',printOrder => 8,perm => 'rw',type => 'ModelSEED::varchar',req => 1},
		{name => 'class',printOrder => 3,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},#gramPositive,gramNegative,archaea,eurkaryote
		{name => 'taxonomy',printOrder => 4,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'cksum',printOrder => -1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'size',printOrder => 5,perm => 'rw',type => 'Int',req => 0},
		{name => 'gc',printOrder => 6,perm => 'rw',type => 'Num',req => 0},
		{name => 'etcType',printOrder => 7,perm => 'rw',type => 'ModelSEED::varchar',len => 1,req => 0},#aerobe,facultativeAnaerobe,obligateAnaerobe
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{User} = {
    parents => ["ModelSEED::Store"],
    class => 'child',
    attributes => [
        {name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
        {name => 'login',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
        {name => 'password',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
        {name => 'email',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""},
        {name => 'firstname',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""},
        {name => 'lastname',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""},
    ],
    subobjects => [],
    primarykeys => [ qw(uuid) ],
    links => [],
    reference_id_types => [ qw(uuid) ],
    version => 1.0,
};

$objectDefinitions->{Biochemistry} = {
	parents => ["ModelSEED::Store"],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'defaultNameSpace',printOrder => 2,perm => 'rw',type => 'Str',len => 32,req => 0,default => "ModelSEED"},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Bool',req => 0,default => "1"},
		{name => 'public',printOrder => -1,perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
	],
	subobjects => [
		{name => "compartments",printOrder => 0,class => "Compartment",type => "child"},
		{name => "compounds",printOrder => 3,class => "Compound",type => "child"},
		{name => "reactions",printOrder => 4,class => "Reaction",type => "child"},
		{name => "media",printOrder => 2,class => "Media",type => "child"},
		{name => "compoundSets",class => "CompoundSet",type => "child"},
		{name => "reactionSets",class => "ReactionSet",type => "child"},
		{name => "aliasSets",class => "AliasSet",type => "child"},
		{name => "cues",printOrder => 1,class => "Cue",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid alias) ],
    version => 1.0,
};

$objectDefinitions->{AliasSet} = {
	parents => ['Ref'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'name',printOrder => 0,perm => 'rw',type => 'Str',req => 1}, #KEGG, GenBank, SEED, ModelSEED
		{name => 'source',printOrder => 0,perm => 'rw',type => 'Str',req => 1}, #url or pubmed ID indicating where the alias set came from
		{name => 'class',printOrder => 0,perm => 'rw',type => 'Str',req => 1}, #
		{name => 'attribute',printOrder => 0,perm => 'rw',type => 'Str',req => 1}, #
		{name => 'aliases',printOrder => 0,perm => 'rw',type => 'HashRef',req => 0,default => "sub {return {};}" } #url or pubmed ID indicating where the alias set came from
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Compartment} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',printOrder => 1,perm => 'rw',type => 'Str',len => 2,req => 1},
		{name => 'name',printOrder => 2,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'hierarchy',printOrder => 3,perm => 'rw',type => 'Int',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Cue} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'abbreviation',printOrder => 2,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'cksum',printOrder => -1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'unchargedFormula',printOrder => -1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'formula',printOrder => 3,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'mass',printOrder => 4,perm => 'rw',type => 'Num',req => 0},
		{name => 'defaultCharge',printOrder => 5,perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaG',printOrder => 6,perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',printOrder => 7,perm => 'rw',type => 'Num',req => 0},
		{name => 'smallMolecule',printOrder => 8,perm => 'rw',type => 'Bool',req => 0},
		{name => 'priority',printOrder => 9,perm => 'rw',type => 'Int',req => 0},
	],
	subobjects => [
		{name => "structures",class => "CompoundStructure",type => "encompassed"},
		{name => "pks",class => "CompoundPk",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Compound} = {
	alias => "Biochemistry",
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'abbreviation',printOrder => 2,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'cksum',printOrder => -1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'unchargedFormula',printOrder => -1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'formula',printOrder => 3,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'mass',printOrder => 4,perm => 'rw',type => 'Num',req => 0},
		{name => 'defaultCharge',printOrder => 5,perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'deltaG',printOrder => 6,perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',printOrder => 7,perm => 'rw',type => 'Num',req => 0},
	],
	subobjects => [
		{name => "compoundCues",class => "CompoundCue",type => "encompassed"},
		{name => "structures",class => "CompoundStructure",type => "encompassed"},
		{name => "pks",class => "CompoundPk",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{CompoundCue} = {
	parents => ['Compound'],
	class => 'encompassed',
	attributes => [
		{name => 'cue_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'count',printOrder => 0,perm => 'rw',type => 'Int',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(type cksum compound_uuid) ],
	links => [
		{name => "cue",attribute => "cue_uuid",parent => "Biochemistry",method=>"cues"}
	]
};

$objectDefinitions->{CompoundStructure} = {
	parents => ['Compound'],
	class => 'encompassed',
	attributes => [
		{name => 'structure',printOrder => 0,perm => 'rw',type => 'Str',req => 1},
		{name => 'cksum',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(type cksum compound_uuid) ],
	links => []
};

$objectDefinitions->{CompoundPk} = {
	parents => ['Compound'],
	class => 'encompassed',
	attributes => [
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',len => 45,req => 0},
		{name => 'atom',printOrder => 0,perm => 'rw',type => 'Int',req => 0},
		{name => 'pk',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',len => 1,req => 1},
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
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'abbreviation',printOrder => 2,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'cksum',printOrder => -1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'deltaG',printOrder => 8,perm => 'rw',type => 'Num',req => 0},
		{name => 'deltaGErr',printOrder => 9,perm => 'rw',type => 'Num',req => 0},
		{name => 'direction',printOrder => 5,perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'thermoReversibility',printOrder => 6,perm => 'rw',type => 'Str',len => 1,req => 0},
		{name => 'defaultProtons',printOrder => 7,perm => 'rw',type => 'Num',req => 0},
		{name => 'status',printOrder => 10,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [
		{name => "reactionCues",class => "ReactionCue",type => "encompassed"},
		{name => "reagents",class => "Reagent",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{ReactionCue} = {
	parents => ['Reaction'],
	class => 'encompassed',
	attributes => [
		{name => 'cue_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'count',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw() ],
	links => [
		{name => "cue",attribute => "cue_uuid",parent => "Biochemistry",method=>"cues"}
	]
};

$objectDefinitions->{Reagent} = {
	parents => ['Reaction'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
        {name => 'destinationCompartment_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 36, req =>1},
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
        {name => 'isTransport', printOrder => 0, perm => 'rw', type => 'Bool', default => "0" },
		{name => 'isCofactor',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => "0"},
	],
	subobjects => [],
	primarykeys => [ qw(reaction_uuid compound_uuid compartment_uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method=>"compounds"},
        {name => "destinationCompartment",attribute => "destinationCompartment_uuid",parent=>"Biochemistry",method=>"compartments"},
	]
};

$objectDefinitions->{Media} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'isDefined',printOrder => 4,perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'isMinimal',printOrder => 5,perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'id',printOrder => 1,perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',printOrder => 2,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'type',printOrder => 6,perm => 'rw',type => 'Str',len => 1,req => 0,default => "unknown"},#minimal,defined,predictedminimal,undefined,unknown
	],
	subobjects => [
		{name => "mediacompounds",class => "MediaCompound",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{MediaCompound} = {
	parents => ['Media'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'concentration',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "0.001"},
		{name => 'maxFlux',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "100"},
		{name => 'minFlux',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "-100"},
	],
	subobjects => [],
	primarykeys => [ qw(media_uuid compound_uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method=>"compounds"},
	]
};

$objectDefinitions->{CompoundSet} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',printOrder => 0,perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'class',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [
		{name => "compounds",class => "CompoundSetCompound",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{CompoundSetCompound} = {
	parents => ['CompoundSet'],
	class => 'encompassed',
	attributes => [
		{name => 'compound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method=>"compounds"}
	]
};

$objectDefinitions->{ReactionSet} = {
	parents => ['Biochemistry'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',printOrder => 0,perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'name',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'class',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',len => 32,req => 1},
	],
	subobjects => [
		{name => "reactions",class => "ReactionSetReaction",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{ReactionSetReaction} = {
	parents => ['ReactionSet'],
	class => 'encompassed',
	attributes => [
		{name => 'reaction_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method=>"reactions"}
	]
};

$objectDefinitions->{Model} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'defaultNameSpace',printOrder => 3,perm => 'rw',type => 'Str',len => 32,req => 0,default => "ModelSEED"},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 1},
		{name => 'name',printOrder => 2,perm => 'rw',type => 'Str',len => 32,req => 0,default => ""},
		{name => 'version',printOrder => 3,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'type',printOrder => 5,perm => 'rw',type => 'Str',len => 32,req => 0,default => "Singlegenome"},
		{name => 'status',printOrder => 7,perm => 'rw',type => 'Str',len => 32,req => 0},
		{name => 'growth',printOrder => 6,perm => 'rw',type => 'Num',req => 0},
		{name => 'current',printOrder => 4,perm => 'rw',type => 'Int',req => 0,default => "1"},
		{name => 'mapping_uuid',printOrder => 8,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'biochemistry_uuid',printOrder => 9,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'annotation_uuid',printOrder => 10,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
	],
	subobjects => [
		{name => "biomasses",printOrder => 0,class => "Biomass",type => "child"},
		{name => "modelcompartments",printOrder => 1,class => "ModelCompartment",type => "child"},
		{name => "modelcompounds",printOrder => 2,class => "ModelCompound",type => "child"},
		{name => "modelreactions",printOrder => 3,class => "ModelReaction",type => "child"},
        {name => "fbaFormulations",printOrder => -1,class => "FBAFormulation", type => "child"},
        {name => "Gapfillingformulations", printOrder => -1, class => "GapfillingFormulation", type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "biochemistry",attribute => "biochemistry_uuid",parent => "ModelSEED::Store",method=>"Biochemistry", weak => 0},
		{name => "mapping",attribute => "mapping_uuid",parent => "ModelSEED::Store",method=>"Mapping", weak => 0},
		{name => "annotation",attribute => "annotation_uuid",parent => "ModelSEED::Store",method=>"Annotation", weak => 0},
		{name => "modelanalysis",attribute => "modelanalysis_uuid",parent => "ModelSEED::Store",method=>"ModelAnalysis", weak => 0},
	],
    reference_id_types => [ qw(uuid alias) ],
    version => 1.0,
};

$objectDefinitions->{Biomass} = {
	alias => "Model",
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'dna',printOrder => 3,perm => 'rw',type => 'Num',req => 0,default => "0.05"},
		{name => 'rna',printOrder => 4,perm => 'rw',type => 'Num',req => 0,default => "0.1"},
		{name => 'protein',printOrder => 5,perm => 'rw',type => 'Num',req => 0,default => "0.5"},
		{name => 'cellwall',printOrder => 6,perm => 'rw',type => 'Num',req => 0,default => "0.15"},
		{name => 'lipid',printOrder => 7,perm => 'rw',type => 'Num',req => 0,default => "0.05"},
		{name => 'cofactor',printOrder => 8,perm => 'rw',type => 'Num',req => 0,default => "0.15"},
		{name => 'energy',printOrder => 9,perm => 'rw',type => 'Num',req => 0,default => "40"},
	],
	subobjects => [
		{name => "biomasscompounds",class => "BiomassCompound",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{BiomassCompound} = {
	parents => ['Biomass'],
	class => 'encompassed',
	attributes => [
		{name => 'modelcompound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(biomass_uuid modelcompound_uuid) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",method=>"modelcompounds"},
	]
};

$objectDefinitions->{ModelCompartment} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'compartment_uuid',printOrder => 5,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartmentIndex',printOrder => 2,perm => 'rw',type => 'Int',req => 1},
		{name => 'label',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'pH',printOrder => 3,perm => 'rw',type => 'Num',req => 0,default => "7"},
		{name => 'potential',printOrder => 4,perm => 'rw',type => 'Num',req => 0,default => "0"},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method=>"compartments"}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{ModelCompound} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'compound_uuid',printOrder => 6,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'charge',printOrder => 3,perm => 'rw',type => 'Num',req => 0},
		{name => 'formula',printOrder => 4,perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'modelcompartment_uuid',printOrder => 5,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(model_uuid uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method=>"compounds"},
		{name => "modelcompartment",attribute => "modelcompartment_uuid",parent => "Model",method=>"modelcompartments"}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{ModelReaction} = {
	parents => ['Model'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'reaction_uuid',printOrder => -1,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'direction',printOrder => -1,perm => 'rw',type => 'Str',len => 1,req => 0,default => "="},
		{name => 'protons',printOrder => -1,perm => 'rw',type => 'Num',req => 0,default => 0},
		{name => 'modelcompartment_uuid',printOrder => -1,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [
		{name => "modelReactionProteins",class => "ModelReactionProtein",type => "encompassed"},
		{name => "modelReactionReagents",class => "ModelReactionReagent",type => "encompassed"},
	],
	primarykeys => [ qw(model_uuid uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method=>"reactions"},
		{name => "modelcompartment",attribute => "modelcompartment_uuid",parent => "Model",method=>"modelcompartments"}
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{ModelReactionReagent} = {
	parents => ['ModelReaction'],
	class => 'encompassed',
	attributes => [
		{name => 'modelcompound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',len => 36,req => 1},
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(modelcompound_uuid) ],
	links => [
		{name => "modelcompound",attribute => "modelcompound_uuid",parent => "Model",method=>"modelcompounds"}
	]
};

$objectDefinitions->{ModelReactionProtein} = {
	parents => ['ModelReaction'],
	class => 'encompassed',
	attributes => [
		{name => 'complex_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'note',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""}
	],
	subobjects => [
		{name => "modelReactionProteinSubunits",class => "ModelReactionProteinSubunit",type => "encompassed"},
	],
	primarykeys => [ qw() ],
	links => [
		{name => "complex",attribute => "complex_uuid",parent => "Mapping",method=>"complexes"}
	]
};

$objectDefinitions->{ModelReactionProteinSubunit} = {
	parents => ['ModelReactionProtein'],
	class => 'encompassed',
	attributes => [
		{name => 'role_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'triggering',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => "1"},
		{name => 'optional',printOrder => 0,perm => 'rw',type => 'Bool',req => 0,default => "0"},
		{name => 'note',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""},
	],
	subobjects => [
		{name => "modelReactionProteinSubunitGenes",class => "ModelReactionProteinSubunitGene",type => "encompassed"},
	],
	primarykeys => [ qw() ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",method=>"roles"}
	]
};

$objectDefinitions->{ModelReactionProteinSubunitGene} = {
	parents => ['ModelReactionProteinSubunit'],
	class => 'encompassed',
	attributes => [
		{name => 'feature_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw() ],
	links => [
		{name => "feature",attribute => "feature_uuid",parent => "Annotation",method=>"features"}
	]
};

$objectDefinitions->{Annotation} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'defaultNameSpace',printOrder => 3,perm => 'rw',type => 'Str',len => 32,req => 0,default => "SEED"},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'mapping_uuid',printOrder => 2,perm => 'rw',type => 'ModelSEED::uuid'}
	],
	subobjects => [
		{name => "genomes",printOrder => 0,class => "Genome",type => "child"},
		{name => "features",printOrder => 1,class => "Feature",type => "child"},
		{name => "subsystemStates",printOrder => 2,class => "SubsystemState",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "mapping",attribute => "mapping_uuid",parent => "ModelSEED::Store",method=>"Mapping", weak => 0},
	],
    reference_id_types => [ qw(uuid alias) ],
    version => 1.0,
};

$objectDefinitions->{Feature} = {
	parents => ['Annotation'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'id',printOrder => 1,perm => 'rw',type => 'Str',len => 32,req => 1},
		{name => 'cksum',printOrder => -1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'genome_uuid',printOrder => -1,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'start',printOrder => 3,perm => 'rw',type => 'Int',req => 0},
		{name => 'stop',printOrder => 4,perm => 'rw',type => 'Int',req => 0},
		{name => 'contig',printOrder => 5,perm => 'rw',type => 'Str',req => 0},
		{name => 'direction',printOrder => 6,perm => 'rw',type => 'Str',req => 0},
		{name => 'sequence',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'type',printOrder => 7,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [
		{name => "featureroles",class => "FeatureRole",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "genome",attribute => "genome_uuid",parent => "Annotation",method=>"genomes"},
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{FeatureRole} = {
	parents => ['Feature'],
	class => 'encompassed',
	attributes => [
		{name => 'role_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartment',printOrder => 0,perm => 'rw',type => 'Str',default => "unknown"},
		{name => 'comment',printOrder => 0,perm => 'rw',type => 'Str',default => ""},
		{name => 'delimiter',printOrder => 0,perm => 'rw',type => 'Str',default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(annotation_uuid feature_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",method=>"roles"},
	]
};

$objectDefinitions->{SubsystemState} = {
	parents => ['Annotation'],
	class => 'child',
	attributes => [
		{name => 'roleset_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'name',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'variant',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Mapping} = {
	parents => ['ModelSEED::Store'],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'defaultNameSpace',printOrder => 2,perm => 'rw',type => 'Str',len => 32,req => 0,default => "SEED"},
		{name => 'biochemistry_uuid',printOrder => 3,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
	],
	subobjects => [
		{name => "universalReactions",printOrder => 0,class => "UniversalReaction",type => "child"},
		{name => "biomassTemplates",printOrder => 1,class => "BiomassTemplate",type => "child"},
		{name => "roles",printOrder => 2,class => "Role",type => "child"},
		{name => "rolesets",printOrder => 3,class => "RoleSet",type => "child"},
		{name => "complexes",printOrder => 4,class => "Complex",type => "child"},
		{name => "aliasSets",class => "AliasSet",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "biochemistry",attribute => "biochemistry_uuid",parent => "ModelSEED::Store",method=>"Biochemistry", weak => 0},
	],
    reference_id_types => [ qw(uuid alias) ],
    version => 1.0,
};

$objectDefinitions->{UniversalReaction} = {
	parents => ['Mapping'],
	class => 'encompassed',
	attributes => [
		{name => 'type',printOrder => 4,perm => 'rw',type => 'Str',req => 1},
		{name => 'reaction_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method=>"reactions"},
	]
};

$objectDefinitions->{BiomassTemplate} = {
	parents => ['Mapping'],
	class => 'encompassed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'class',printOrder => 1,perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'dna',printOrder => 2,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'rna',printOrder => 3,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'protein',printOrder => 4,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'lipid',printOrder => 5,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'cellwall',printOrder => 6,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'cofactor',printOrder => 7,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'energy',printOrder => 8,perm => 'rw',type => 'Num',req => 0,default => "0"}
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
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'class',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'compound_uuid',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'coefficientType',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "0"},
		{name => 'coefficient',printOrder => 0,perm => 'rw',type => 'Num',req => 0,default => "0"},
		{name => 'condition',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "0"},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method=>"compounds"},
	]
};

$objectDefinitions->{Role} = {
	alias => "Mapping",
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'seedfeature',printOrder => 2,perm => 'rw',type => 'Str',len => 36,req => 0}
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{RoleSet} = {
	alias => "Mapping",
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'public',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 3,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'class',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'subclass',printOrder => 2,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => "unclassified"},
		{name => 'type',printOrder => 4,perm => 'rw',type => 'Str',len => 32,req => 1}
	],
	subobjects => [
		{name => "rolesetroles",class => "RoleSetRole",type => "encompassed"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{RoleSetRole} = {
	parents => ['RoleSet'],
	class => 'encompassed',
	attributes => [
		{name => 'role_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",method=>"roles"}
	]
};

$objectDefinitions->{Complex} = {
	alias => "Mapping",
	parents => ['Mapping'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'locked',printOrder => -1,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'name',printOrder => 1,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
	],
	subobjects => [
		{name => "complexreactions",class => "ComplexReaction",type => "encompassed"},
		{name => "complexroles",class => "ComplexRole",type => "encompassed"}
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{ComplexRole} = {
	parents => ['Complex'],
	class => 'encompassed',
	attributes => [
		{name => 'role_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'optional',printOrder => 0,perm => 'rw',type => 'Int',req => 0,default => "0"},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',len => 1,req => 0,default => "G"},
		{name => 'triggering',printOrder => 0,perm => 'rw',type => 'Int',len => 1,req => 0,default => "1"}
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "role",attribute => "role_uuid",parent => "Mapping",method=>"roles"}
	]
};

$objectDefinitions->{ComplexReaction} = {
	parents => ['Complex'],
	class => 'encompassed',
	attributes => [
		{name => 'reaction_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 1},
		{name => 'compartment',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => "cytosol"}
	],
	subobjects => [],
	primarykeys => [ qw(complex_uuid role_uuid) ],
	links => [
		{name => "reaction",attribute => "reaction_uuid",parent => "Biochemistry",method=>"reactions"}
	]
};

#ORPHANED OBJECTS THAT STILL NEED TO BE BUILT INTO AN OBJECT TREE
$objectDefinitions->{Strain} = {
	parents => ['Genome'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'modDate',printOrder => -1,perm => 'rw',type => 'Str',req => 0},
		{name => 'name',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
		{name => 'source',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 1},
		{name => 'class',printOrder => 0,perm => 'rw',type => 'ModelSEED::varchar',req => 0,default => ""},
	],
	subobjects => [
		{name => "deletions",class => "Deletion",type => "child"},
		{name => "insertions",class => "Insertion",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Deletion} = {
	parents => ['Genome'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'start',printOrder => 0,perm => 'rw',type => 'Int',req => 0},
		{name => 'stop',printOrder => 0,perm => 'rw',type => 'Int',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Insertion} = {
	parents => ['Genome'],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'insertionTarget',printOrder => 0,perm => 'rw',type => 'Int',req => 0},
		{name => 'sequence',printOrder => 0,perm => 'rw',type => 'Str',req => 0,default => ""},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{Experiment} = {
	parents => ["ModelSEED::Store"],
	class => 'indexed',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'genome_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},#I think this should be Strain.Right now, we�re linking an experiment to a single GenomeUUID here, but I think it makes more sense to link to a single StrainUUID, which is what we do in the Price DB.  
		{name => 'name',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'description',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'institution',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'source',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "genome",attribute => "genome_uuid",parent => "ModelSEED::Store",method=>"genomes"},
	],
    reference_id_types => [ qw(uuid alias) ],
    version => 1.0,
};

$objectDefinitions->{ExperimentDataPoint} = {
	parents => ["Experiment"],
	class => 'child',
	attributes => [
		{name => 'uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'strain_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},#Not needed if it�s in the experiment table? I think we need to be consistent in defining where in these tables to put e.g. genetic perturbations done in an experiment.
		{name => 'media_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'pH',printOrder => 0,perm => 'rw',type => 'Num',req => 0},
		{name => 'temperature',printOrder => 0,perm => 'rw',type => 'Num',req => 0},
		{name => 'buffers',printOrder => 0,perm => 'rw',type => 'Str',req => 0},#There could be multiple buffers in a single media. Would this be listed in the Media table? Multiple buffers in single media isn�t something we�ve run across yet and seems like a rarity at best, since their purpose is maintaining pH.  We discussed just listing the buffer here, without amount, because the target pH should dictate the amount of buffer. 
		{name => 'phenotype',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'notes',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'growthMeasurement',printOrder => 0,perm => 'rw',type => 'Num',req => 0},#Would these be better in their own table? IT�s just another type of measurement just like the flux, metabolite, etc... One reason to keep the growth measurements here is unit consistency; moving them to the other table with the other flux measurements would require a clear division between growth rates and secretion/uptake rates to distinguish between 1/h and mmol/gDW/h. Rather than do that, I think keeping them in separate tables makes for an easy, logical division. 
		{name => 'growthMeasurementType',printOrder => 0,perm => 'rw',type => 'Str',req => 0},#Would these be better in their own table?
	],
	subobjects => [
		{name => "fluxMeasurements",class => "FluxMeasurement",type => "child"},
		{name => "uptakeMeasurements",class => "UptakeMeasurement",type => "child"},
		{name => "metaboliteMeasurements",class => "MetaboliteMeasurement",type => "child"},
		{name => "geneMeasurements",class => "GeneMeasurement",type => "child"},
	],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "strain",attribute => "strain_uuid",parent => "Genome",method=>"strains"},
		{name => "media",attribute => "media_uuid",parent => "Biochemistry",method=>"media"},
	],
    reference_id_types => [ qw(uuid) ],
};

$objectDefinitions->{FluxMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',printOrder => 0,perm => 'rw',type => 'Str',req => 0},#This could get confusing. Make sure the rate is defined relative to the way that the reaction itself is defined (i.e. even if the directionality of the reaction is <= we should define the rate relative to the forward direction, and if it is consistent with the directionality constraint it would be negative)
		{name => 'reacton_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'compartment_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "reaction",attribute => "reacton_uuid",parent => "Biochemistry",method=>"reactions"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method=>"compartments"},
	],
};

$objectDefinitions->{UptakeMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'compound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'type',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method=>"compounds"},
	],
};

$objectDefinitions->{MetaboliteMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',printOrder => 0,perm => 'rw',type => 'Str',req => 0},#In metabolomic experiments it is often hard to measure precisely whether a metabolite is present or not. and (even more so) it�s concentration. However, I imagine it is possible to guess a �probability� of particular compounds being present or not. I wanted to talk to one of the guys at Argonne (The guy who was trying to schedule the workshop for KBase) about metabolomics but we ran out of time. We should consult with a metabolomics expert on what a realistic thing to put into this table would be.
		{name => 'compound_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'compartment_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},#I changed this from �extracellular [0/1]� since we could techincally measure them in any given compartment, not just cytosol vs. extracellular
		{name => 'method',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "compound",attribute => "compound_uuid",parent => "Biochemistry",method=>"compounds"},
		{name => "compartment",attribute => "compartment_uuid",parent => "Biochemistry",method=>"compartments"},
	],
};

$objectDefinitions->{GeneMeasurement} = {
	parents => ["ExperimentDataPoint"],
	class => 'encompassed',
	attributes => [
		{name => 'value',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
		{name => 'feature_uuid',printOrder => 0,perm => 'rw',type => 'ModelSEED::uuid',req => 0},
		{name => 'method',printOrder => 0,perm => 'rw',type => 'Str',req => 0},
	],
	subobjects => [],
	primarykeys => [ qw(uuid) ],
	links => [
		{name => "feature",attribute => "feature_uuid",parent => "Genome",method=>"features"},
	],
};

sub objectDefinitions {
	return $objectDefinitions;
}

1;
