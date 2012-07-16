########################################################################
# ModelSEED::MS::Factories - This is the factory for producing the moose objects from the SEED data
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use ModelSEED::utilities;
use Data::Dumper;
package ModelSEED::MS::Factories::ExchangeFormatFactory;
use Moose;
use namespace::autoclean;
#***********************************************************************************************************
# ATTRIBUTES:
#***********************************************************************************************************

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 buildFBAFormulation
Definition:
	ModelSEED::MS::FBAFormulation = buildFBAFormulation({
		array => [string],
		filename => string,
		text => string,
		model => ModelSEED::MS::Model
	});
Description:
	Parses the FBA formulation exchange object
=cut
sub buildFBAFormulation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["model"],{
		text => undef,
		filename => undef,
		overrides => {}
	});
	my $model = $args->{model};
	my $data = $self->parseExchangeFileArray($args);
	#Setting default values for exchange format attributes
	$data = ModelSEED::utilities::ARGS($data,[],{
		media => "Media/name/Complete",
		type => "singlegrowth",
		simpleThermoConstraints => 0,
		thermodynamicConstraints => 0,
		noErrorThermodynamicConstraints => 0,
		minimizeErrorThermodynamicConstraints => 0,
		fva => 0,
		notes => "",
		comboDeletions => 0,
		fluxMinimization => 0,
		findMinimalMedia => 0,
		objectiveConstraintFraction => 0.1,
		allReversible => 0,
		dilutionConstraints => 0,
		uptakeLimits => "none",
		geneKO => "none",
		reactionKO => "none",
		parameters => "none",
		numberOfSolutions => 1,
		defaultMaxFlux => 100,
		defaultMaxDrainFlux => 0,
		defaultMinDrainFlux => -100,
		maximizeObjective => 1,
		decomposeReversibleFlux => 0,
		decomposeReversibleDrainFlux => 0,
		fluxUseVariables => 0,
		drainfluxUseVariables => 0,
		fbaConstraints => [],
		fbaObjectiveTerms => [{
			variableType => "biomassflux",
			id => "Biomass/id/bio00001",
			coefficient => 1
		}]
	});
	#Finding (or creating) the media
	(my $media) = $model->interpretReference($data->{media},"Media");
	if (!defined($media)) {
		ModelSEED::utilities::ERROR("Media referenced in formulation not found in database: ".$data->{media});
	}
	#print STDERR Data::Dumper->Dump([$data]);
	#Creating objects and populating with provenance objects
	my $form = ModelSEED::MS::FBAFormulation->new({
		parent => $model,
		media_uuid => $media->uuid(),
		type => $data->{type},
		notes => $data->{notes},
		growthConstraint => $data->{growthConstraint},
		simpleThermoConstraints => $data->{simpleThermoConstraints},
		thermodynamicConstraints => $data->{thermodynamicConstraints},
		noErrorThermodynamicConstraints => $data->{noErrorThermodynamicConstraints},
		minimizeErrorThermodynamicConstraints => $data->{minimizeErrorThermodynamicConstraints},
		fva => $data->{fva},
		comboDeletions => $data->{comboDeletions},
		fluxMinimization => $data->{fluxMinimization},
		findMinimalMedia => $data->{findMinimalMedia},
		objectiveConstraintFraction => $data->{objectiveConstraintFraction},
		allReversible => $data->{allReversible},
		uptakeLimits => $self->stringToHash($data->{uptakeLimits}),
		defaultMaxFlux => $data->{defaultMaxFlux},
		defaultMaxDrainFlux => $data->{defaultMaxDrainFlux},
		defaultMinDrainFlux => $data->{defaultMinDrainFlux},
		maximizeObjective => $data->{maximizeObjective},
		decomposeReversibleFlux => $data->{decomposeReversibleFlux},
		decomposeReversibleDrainFlux => $data->{decomposeReversibleDrainFlux},
		fluxUseVariables => $data->{fluxUseVariables},
		drainfluxUseVariables => $data->{drainfluxUseVariables},
		parameters => $self->stringToHash($data->{parameters}),
		numberOfSolutions => $data->{numberOfSolutions},
	});
	$form->parseObjectiveTerms({objTerms => $data->{fbaObjectiveTerms}});
	$form->parseGeneKOList({string => $data->{geneKO}});
	$form->parseReactionKOList({string => $data->{reactionKO}});
	$form->parseConstraints({constraints => $data->{fbaConstraints}});
	return $form;
}
=head3 buildGapfillingFormulation
Definition:
	ModelSEED::MS::FBAFormulation = buildGapfillingFormulation({
		array => [string],
		filename => string,
		text => string,
		model => ModelSEED::MS::Model
	});
Description:
	Parses the FBA formulation exchange object
=cut
sub buildGapfillingFormulation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["model"],{
		text => undef,
		filename => undef,
		overrides => {}
	});
	my $model = $args->{model};
	$args->{overrides}->{fbaFormulation}->{model} = $model;
	my $fbaform = $self->buildFBAFormulation($args->{overrides}->{fbaFormulation});
	my $data = $self->parseExchangeFileArray($args);
	#Setting default values for exchange format attributes
	$data = ModelSEED::utilities::ARGS($data,[],{
		fbaFormulation => $fbaform,
		balancedReactionsOnly => 1,
		guaranteedReactions => "Reaction/ModelSEED/rxn13782|Reaction/ModelSEED/rxn13783|Reaction/ModelSEED/rxn13784|Reaction/ModelSEED/rxn05294|Reaction/ModelSEED/rxn05295|Reaction/ModelSEED/rxn05296|Reaction/ModelSEED/rxn10002|Reaction/ModelSEED/rxn10088|Reaction/ModelSEED/rxn11921|Reaction/ModelSEED/rxn11922|Reaction/ModelSEED/rxn10200|Reaction/ModelSEED/rxn11923|Reaction/ModelSEED/rxn05029",
		blacklistedReactions => "Reaction/ModelSEED/rxn12985|Reaction/ModelSEED/rxn00238|Reaction/ModelSEED/rxn07058|Reaction/ModelSEED/rxn05305|Reaction/ModelSEED/rxn00154|Reaction/ModelSEED/rxn09037|Reaction/ModelSEED/rxn10643|Reaction/ModelSEED/rxn11317|Reaction/ModelSEED/rxn05254|Reaction/ModelSEED/rxn05257|Reaction/ModelSEED/rxn05258|Reaction/ModelSEED/rxn05259|Reaction/ModelSEED/rxn05264|Reaction/ModelSEED/rxn05268|Reaction/ModelSEED/rxn05269|Reaction/ModelSEED/rxn05270|Reaction/ModelSEED/rxn05271|Reaction/ModelSEED/rxn05272|Reaction/ModelSEED/rxn05273|Reaction/ModelSEED/rxn05274|Reaction/ModelSEED/rxn05275|Reaction/ModelSEED/rxn05276|Reaction/ModelSEED/rxn05277|Reaction/ModelSEED/rxn05278|Reaction/ModelSEED/rxn05279|Reaction/ModelSEED/rxn05280|Reaction/ModelSEED/rxn05281|Reaction/ModelSEED/rxn05282|Reaction/ModelSEED/rxn05283|Reaction/ModelSEED/rxn05284|Reaction/ModelSEED/rxn05285|Reaction/ModelSEED/rxn05286|Reaction/ModelSEED/rxn05963|Reaction/ModelSEED/rxn05964|Reaction/ModelSEED/rxn05971|Reaction/ModelSEED/rxn05989|Reaction/ModelSEED/rxn05990|Reaction/ModelSEED/rxn06041|Reaction/ModelSEED/rxn06042|Reaction/ModelSEED/rxn06043|Reaction/ModelSEED/rxn06044|Reaction/ModelSEED/rxn06045|Reaction/ModelSEED/rxn06046|Reaction/ModelSEED/rxn06079|Reaction/ModelSEED/rxn06080|Reaction/ModelSEED/rxn06081|Reaction/ModelSEED/rxn06086|Reaction/ModelSEED/rxn06087|Reaction/ModelSEED/rxn06088|Reaction/ModelSEED/rxn06089|Reaction/ModelSEED/rxn06090|Reaction/ModelSEED/rxn06091|Reaction/ModelSEED/rxn06092|Reaction/ModelSEED/rxn06138|Reaction/ModelSEED/rxn06139|Reaction/ModelSEED/rxn06140|Reaction/ModelSEED/rxn06141|Reaction/ModelSEED/rxn06145|Reaction/ModelSEED/rxn06217|Reaction/ModelSEED/rxn06218|Reaction/ModelSEED/rxn06219|Reaction/ModelSEED/rxn06220|Reaction/ModelSEED/rxn06221|Reaction/ModelSEED/rxn06222|Reaction/ModelSEED/rxn06223|Reaction/ModelSEED/rxn06235|Reaction/ModelSEED/rxn06362|Reaction/ModelSEED/rxn06368|Reaction/ModelSEED/rxn06378|Reaction/ModelSEED/rxn06474|Reaction/ModelSEED/rxn06475|Reaction/ModelSEED/rxn06502|Reaction/ModelSEED/rxn06562|Reaction/ModelSEED/rxn06569|Reaction/ModelSEED/rxn06604|Reaction/ModelSEED/rxn06702|Reaction/ModelSEED/rxn06706|Reaction/ModelSEED/rxn06715|Reaction/ModelSEED/rxn06803|Reaction/ModelSEED/rxn06811|Reaction/ModelSEED/rxn06812|Reaction/ModelSEED/rxn06850|Reaction/ModelSEED/rxn06901|Reaction/ModelSEED/rxn06971|Reaction/ModelSEED/rxn06999|Reaction/ModelSEED/rxn07123|Reaction/ModelSEED/rxn07172|Reaction/ModelSEED/rxn07254|Reaction/ModelSEED/rxn07255|Reaction/ModelSEED/rxn07269|Reaction/ModelSEED/rxn07451|Reaction/ModelSEED/rxn09037|Reaction/ModelSEED/rxn10018|Reaction/ModelSEED/rxn10077|Reaction/ModelSEED/rxn10096|Reaction/ModelSEED/rxn10097|Reaction/ModelSEED/rxn10098|Reaction/ModelSEED/rxn10099|Reaction/ModelSEED/rxn10101|Reaction/ModelSEED/rxn10102|Reaction/ModelSEED/rxn10103|Reaction/ModelSEED/rxn10104|Reaction/ModelSEED/rxn10105|Reaction/ModelSEED/rxn10106|Reaction/ModelSEED/rxn10107|Reaction/ModelSEED/rxn10109|Reaction/ModelSEED/rxn10111|Reaction/ModelSEED/rxn10403|Reaction/ModelSEED/rxn10410|Reaction/ModelSEED/rxn10416|Reaction/ModelSEED/rxn11313|Reaction/ModelSEED/rxn11316|Reaction/ModelSEED/rxn11318|Reaction/ModelSEED/rxn11353|Reaction/ModelSEED/rxn05224|Reaction/ModelSEED/rxn05795|Reaction/ModelSEED/rxn05796|Reaction/ModelSEED/rxn05797|Reaction/ModelSEED/rxn05798|Reaction/ModelSEED/rxn05799|Reaction/ModelSEED/rxn05801|Reaction/ModelSEED/rxn05802|Reaction/ModelSEED/rxn05803|Reaction/ModelSEED/rxn05804|Reaction/ModelSEED/rxn05805|Reaction/ModelSEED/rxn05806|Reaction/ModelSEED/rxn05808|Reaction/ModelSEED/rxn05812|Reaction/ModelSEED/rxn05815|Reaction/ModelSEED/rxn05832|Reaction/ModelSEED/rxn05836|Reaction/ModelSEED/rxn05851|Reaction/ModelSEED/rxn05857|Reaction/ModelSEED/rxn05869|Reaction/ModelSEED/rxn05870|Reaction/ModelSEED/rxn05884|Reaction/ModelSEED/rxn05888|Reaction/ModelSEED/rxn05896|Reaction/ModelSEED/rxn05898|Reaction/ModelSEED/rxn05900|Reaction/ModelSEED/rxn05903|Reaction/ModelSEED/rxn05904|Reaction/ModelSEED/rxn05905|Reaction/ModelSEED/rxn05911|Reaction/ModelSEED/rxn05921|Reaction/ModelSEED/rxn05925|Reaction/ModelSEED/rxn05936|Reaction/ModelSEED/rxn05947|Reaction/ModelSEED/rxn05956|Reaction/ModelSEED/rxn05959|Reaction/ModelSEED/rxn05960|Reaction/ModelSEED/rxn05980|Reaction/ModelSEED/rxn05991|Reaction/ModelSEED/rxn05992|Reaction/ModelSEED/rxn05999|Reaction/ModelSEED/rxn06001|Reaction/ModelSEED/rxn06014|Reaction/ModelSEED/rxn06017|Reaction/ModelSEED/rxn06021|Reaction/ModelSEED/rxn06026|Reaction/ModelSEED/rxn06027|Reaction/ModelSEED/rxn06034|Reaction/ModelSEED/rxn06048|Reaction/ModelSEED/rxn06052|Reaction/ModelSEED/rxn06053|Reaction/ModelSEED/rxn06054|Reaction/ModelSEED/rxn06057|Reaction/ModelSEED/rxn06059|Reaction/ModelSEED/rxn06061|Reaction/ModelSEED/rxn06102|Reaction/ModelSEED/rxn06103|Reaction/ModelSEED/rxn06127|Reaction/ModelSEED/rxn06128|Reaction/ModelSEED/rxn06129|Reaction/ModelSEED/rxn06130|Reaction/ModelSEED/rxn06131|Reaction/ModelSEED/rxn06132|Reaction/ModelSEED/rxn06137|Reaction/ModelSEED/rxn06146|Reaction/ModelSEED/rxn06161|Reaction/ModelSEED/rxn06167|Reaction/ModelSEED/rxn06172|Reaction/ModelSEED/rxn06174|Reaction/ModelSEED/rxn06175|Reaction/ModelSEED/rxn06187|Reaction/ModelSEED/rxn06189|Reaction/ModelSEED/rxn06203|Reaction/ModelSEED/rxn06204|Reaction/ModelSEED/rxn06246|Reaction/ModelSEED/rxn06261|Reaction/ModelSEED/rxn06265|Reaction/ModelSEED/rxn06266|Reaction/ModelSEED/rxn06286|Reaction/ModelSEED/rxn06291|Reaction/ModelSEED/rxn06294|Reaction/ModelSEED/rxn06310|Reaction/ModelSEED/rxn06320|Reaction/ModelSEED/rxn06327|Reaction/ModelSEED/rxn06334|Reaction/ModelSEED/rxn06337|Reaction/ModelSEED/rxn06339|Reaction/ModelSEED/rxn06342|Reaction/ModelSEED/rxn06343|Reaction/ModelSEED/rxn06350|Reaction/ModelSEED/rxn06352|Reaction/ModelSEED/rxn06358|Reaction/ModelSEED/rxn06361|Reaction/ModelSEED/rxn06369|Reaction/ModelSEED/rxn06380|Reaction/ModelSEED/rxn06395|Reaction/ModelSEED/rxn06415|Reaction/ModelSEED/rxn06419|Reaction/ModelSEED/rxn06420|Reaction/ModelSEED/rxn06421|Reaction/ModelSEED/rxn06423|Reaction/ModelSEED/rxn06450|Reaction/ModelSEED/rxn06457|Reaction/ModelSEED/rxn06463|Reaction/ModelSEED/rxn06464|Reaction/ModelSEED/rxn06466|Reaction/ModelSEED/rxn06471|Reaction/ModelSEED/rxn06482|Reaction/ModelSEED/rxn06483|Reaction/ModelSEED/rxn06486|Reaction/ModelSEED/rxn06492|Reaction/ModelSEED/rxn06497|Reaction/ModelSEED/rxn06498|Reaction/ModelSEED/rxn06501|Reaction/ModelSEED/rxn06505|Reaction/ModelSEED/rxn06506|Reaction/ModelSEED/rxn06521|Reaction/ModelSEED/rxn06534|Reaction/ModelSEED/rxn06580|Reaction/ModelSEED/rxn06585|Reaction/ModelSEED/rxn06593|Reaction/ModelSEED/rxn06609|Reaction/ModelSEED/rxn06613|Reaction/ModelSEED/rxn06654|Reaction/ModelSEED/rxn06667|Reaction/ModelSEED/rxn06676|Reaction/ModelSEED/rxn06693|Reaction/ModelSEED/rxn06730|Reaction/ModelSEED/rxn06746|Reaction/ModelSEED/rxn06762|Reaction/ModelSEED/rxn06779|Reaction/ModelSEED/rxn06790|Reaction/ModelSEED/rxn06791|Reaction/ModelSEED/rxn06792|Reaction/ModelSEED/rxn06793|Reaction/ModelSEED/rxn06794|Reaction/ModelSEED/rxn06795|Reaction/ModelSEED/rxn06796|Reaction/ModelSEED/rxn06797|Reaction/ModelSEED/rxn06821|Reaction/ModelSEED/rxn06826|Reaction/ModelSEED/rxn06827|Reaction/ModelSEED/rxn06829|Reaction/ModelSEED/rxn06839|Reaction/ModelSEED/rxn06841|Reaction/ModelSEED/rxn06842|Reaction/ModelSEED/rxn06851|Reaction/ModelSEED/rxn06866|Reaction/ModelSEED/rxn06867|Reaction/ModelSEED/rxn06873|Reaction/ModelSEED/rxn06885|Reaction/ModelSEED/rxn06891|Reaction/ModelSEED/rxn06892|Reaction/ModelSEED/rxn06896|Reaction/ModelSEED/rxn06938|Reaction/ModelSEED/rxn06939|Reaction/ModelSEED/rxn06944|Reaction/ModelSEED/rxn06951|Reaction/ModelSEED/rxn06952|Reaction/ModelSEED/rxn06955|Reaction/ModelSEED/rxn06957|Reaction/ModelSEED/rxn06960|Reaction/ModelSEED/rxn06964|Reaction/ModelSEED/rxn06965|Reaction/ModelSEED/rxn07086|Reaction/ModelSEED/rxn07097|Reaction/ModelSEED/rxn07103|Reaction/ModelSEED/rxn07104|Reaction/ModelSEED/rxn07105|Reaction/ModelSEED/rxn07106|Reaction/ModelSEED/rxn07107|Reaction/ModelSEED/rxn07109|Reaction/ModelSEED/rxn07119|Reaction/ModelSEED/rxn07179|Reaction/ModelSEED/rxn07186|Reaction/ModelSEED/rxn07187|Reaction/ModelSEED/rxn07188|Reaction/ModelSEED/rxn07195|Reaction/ModelSEED/rxn07196|Reaction/ModelSEED/rxn07197|Reaction/ModelSEED/rxn07198|Reaction/ModelSEED/rxn07201|Reaction/ModelSEED/rxn07205|Reaction/ModelSEED/rxn07206|Reaction/ModelSEED/rxn07210|Reaction/ModelSEED/rxn07244|Reaction/ModelSEED/rxn07245|Reaction/ModelSEED/rxn07253|Reaction/ModelSEED/rxn07275|Reaction/ModelSEED/rxn07299|Reaction/ModelSEED/rxn07302|Reaction/ModelSEED/rxn07651|Reaction/ModelSEED/rxn07723|Reaction/ModelSEED/rxn07736|Reaction/ModelSEED/rxn07878|Reaction/ModelSEED/rxn11417|Reaction/ModelSEED/rxn11582|Reaction/ModelSEED/rxn11593|Reaction/ModelSEED/rxn11597|Reaction/ModelSEED/rxn11615|Reaction/ModelSEED/rxn11617|Reaction/ModelSEED/rxn11619|Reaction/ModelSEED/rxn11620|Reaction/ModelSEED/rxn11624|Reaction/ModelSEED/rxn11626|Reaction/ModelSEED/rxn11638|Reaction/ModelSEED/rxn11648|Reaction/ModelSEED/rxn11651|Reaction/ModelSEED/rxn11665|Reaction/ModelSEED/rxn11666|Reaction/ModelSEED/rxn11667|Reaction/ModelSEED/rxn11698|Reaction/ModelSEED/rxn11983|Reaction/ModelSEED/rxn11986|Reaction/ModelSEED/rxn11994|Reaction/ModelSEED/rxn12006|Reaction/ModelSEED/rxn12007|Reaction/ModelSEED/rxn12014|Reaction/ModelSEED/rxn12017|Reaction/ModelSEED/rxn12022|Reaction/ModelSEED/rxn12160|Reaction/ModelSEED/rxn12161|Reaction/ModelSEED/rxn01267",
		allowableCompartments => "Compartment/id/c|Compartment/id/e|Compartment/id/p",
		reactionActivationBonus => 0,
		drainFluxMultiplier => 1,
		directionalityMultiplier => 1,
		deltaGMultiplier => 1,
		noStructureMultiplier => 1,
		noDeltaGMultiplier => 1,
		biomassTransporterMultiplier => 1,
		singleTransporterMultiplier => 1,
		transporterMultiplier => 1,
		gapfillingGeneCandidates => [],
		reactionSetMultipliers => [],
	});
	#Creating gapfilling formulation object
	my $gapform = ModelSEED::MS::GapfillingFormulation->new({
		parent => $model,
		fbaFormulation_uuid => $fbaform->uuid(),
		fbaFormulation => $fbaform,
		balancedReactionsOnly => $data->{balancedReactionsOnly},
		reactionActivationBonus => $data->{reactionActivationBonus},
		drainFluxMultiplier => $data->{drainFluxMultiplier},
		directionalityMultiplier => $data->{directionalityMultiplier},
		deltaGMultiplier => $data->{deltaGMultiplier},
		noStructureMultiplier => $data->{noStructureMultiplier},
		noDeltaGMultiplier => $data->{noDeltaGMultiplier},
		biomassTransporterMultiplier => $data->{biomassTransporterMultiplier},
		singleTransporterMultiplier => $data->{singleTransporterMultiplier},
		transporterMultiplier => $data->{transporterMultiplier}
	});
	$model->add("fbaFormulations",$fbaform);
	$gapform->parseGeneCandidates({geneCandidates => $data->{gapfillingGeneCandidates}});
	$gapform->parseSetMultipliers({sets => $data->{reactionSetMultipliers}});
	$gapform->parseGuaranteedReactions({string => $data->{guaranteedReactions}});
	$gapform->parseBlacklistedReactions({string => $data->{blacklistedReactions}});
	$gapform->parseAllowableCompartments({string => $data->{allowableCompartments}});
	return $gapform;
}
=head3 stringToHash
Definition:
	{} = stringToHash(string);
Description:
	Parses the input string into a hash using the delimiters "|" and ":"
=cut
sub stringToHash {
	my ($self,$string) = @_;
	my $output = {};
	if ($string ne "none") {
		my $array = [split(/\|/,$string)];
		foreach my $item (@{$array}) {
			my $subarray = [split(/\:/,$item)];
			if (defined($subarray->[1])) {
				$output->{$subarray->[0]} = $subarray->[1];
			}
		}
	}
	return $output;
}

=head3 parseExchangeFileArray
Definition:
	{} = ModelSEED::MS::Biochemistry->parseExchangeFileArray({
		array => [string](undef),
		text => string(undef),
		filename => string(undef)
	});
Description:
	Parses the exchange file array into a attribute and subobject hash
=cut
sub parseExchangeFileArray {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		text => undef,
		filename => undef,
		array => [],
		overrides => {}
	});
	if (defined($args->{filename}) && -e $args->{filename}) {
		$args->{array} = ModelSEED::utilities::LOADFILE($args->{filename}); 
		delete $args->{text};
	}
	if (defined($args->{text})) {
		$args->{array} = [split(/\n/,$args->{text})];
	}
	my $array = $args->{array};
	my $data = {};
	my $section = "none";
	my $headings;
	for (my $i=0; $i < @{$array}; $i++) {
		if ($array->[$i] =~ m/^Attributes/) {
			$section = "attributes";
		} elsif ($array->[$i] eq "}") {
			$section = "none";
		} elsif ($section eq "attributes") {
			$array->[$i] =~ s/^[\s\t]+//g;
			my $arrayTwo = [split(/:/,$array->[$i])];
			$data->{$arrayTwo->[0]} = $arrayTwo->[1];
		} elsif ($array->[$i] =~ m/^([a-zA-Z])\s*\((.+)\)/ && $section eq "none") {
			$section = $1;
			$headings = [split(/\t/,$2)];
		} elsif ($section ne "none") {
			my $arrayTwo = [split(/:/,$array->[$i])];
			my $subobjectData;
			for (my $j=0; $j < @{$headings}; $j++) {
				$subobjectData->{$headings->[$j]} = $arrayTwo->[$j];
			}
			push(@{$data->{$section}},$subobjectData);
		}
	}
	#Setting overrides
	foreach my $key (%{$args->{overrides}}) {
		$data->{$key} = $args->{overrides}->{$key};
	}
	return $data;
}
=head3 buildObjectFromExchangeFileArray
Definition:
	ModelSEED::MS::?? = ModelSEED::MS::Biochemistry->buildObjectFromExchangeFileArray({
		array => [string](REQ)
	});
Description:
	Parses the exchange file array into a attribute and subobject hash
=cut
sub buildObjectFromExchangeFileArray {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["array"],{
		Biochemistry => undef,
		Mapping => undef,
		Model => undef,
		Annotation => undef
	});
	my $data = $self->parseExchangeFileArray($args);
	#The data object must have an ID, which is used to identify the type
	if (!defined($data->{id})) {
		ModelSEED::utilities::ERROR("Input exchange file must have ID!");
	}
	my $refdata = $self->reconcileReference($data->{id});
	delete $data->{id};
	#Checking for shortened names and array-type attributes
	my $dbclass = 'ModelSEED::MS::DB::'.$refdata->{class};
	my $class = 'ModelSEED::MS::'.$refdata->{class};
	for my $attr ( $dbclass->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
			my $name = $attr->name();
			if ($attr->type() eq "attribute") {
				if ($attr->type_constraint() =~ m/ArrayRef/ && defined($data->{$name})) {
					$data->{$name} = [split(/\|/,$data->{$name})];
				}
				if ($name =~ m/(.+)_uuid$/ && !defined($data->{$name})) {
					my $shortname = $1;
					if (defined($data->{$shortname})) {
						$data->{$name} = $data->{$shortname};
						delete $data->{$shortname};
					}
				}
			}
		}
	}
	#Parsing through all attributes looking for and reconciling parent references
	my $parentObjects = {
		Biochemistry => 1,
		Annotation => 1,
		Model => 1,
		Mapping => 1
	};
	my $parents;
	foreach my $att (keys(%{$data})) {
		my $refData = $self->reconcileReference($data->{$att});
		if (defined($refData)) {
			if (defined($parentObjects->{$refData->{class}})) {
				if (defined($args->{$refData->{class}})) {
					$parents->{$refData->{class}} = $args->{$refData->{class}};
				} elsif (defined($args->{store})) {
					$parents->{$refData->{class}} = $self->store()->get_object($data->{$att});	
				}
				if (defined($parents->{$refData->{class}})) {
					$data->{$att} = $parents->{$refData->{class}}->uuid();
				}
			}
		}	
	}
	my $subobjectParents = {
			Reaction => "Biochemistry",
			Media => "Biochemistry",
			Compartment => "Biochemistry"
	};
	my $subobjectAttributes = {
			Reaction => "reactions",
			Media => "media",
			Compartment => "compartments"
	};
	#Parsing through all attributes looking for and reconciling all non-parent references
	foreach my $att (keys(%{$data})) {
		my $refData = $self->reconcileReference($data->{$att});
		if (defined($refData)) {
			if ($refData->{type} eq "uuid") {
				$data->{$att} = $refData->{id};
			} elsif (!defined($parentObjects->{$refData->{class}}) && defined($subobjectParents->{$refData->{class}})) {
				if (defined($parents->{$subobjectParents->{$refData->{class}}})) {
					my $obj;
					if ($refData->{type} eq "name" || $refData->{type} eq "abbreviation") {
						$obj = $parents->{$subobjectParents->{$refData->{class}}}->queryObject($subobjectAttributes->{$refData->{class}},{$refData->{type} => $refData->{id}});
					} else {
						$obj = $parents->{$subobjectParents->{$refData->{class}}}->getObjectByAlias($subobjectAttributes->{$refData->{class}},$refData->{id},$refData->{type});
					}
					if (defined($obj)) {
						$data->{$att} = $obj->uuid();	
					}
				}	
			}
		}	
	}
	return $class->new($data);
}
=head3 reconcileReference
Definition:
	{
		class => string,
		id => string,
		type => string
	} = ModelSEED::MS::Biochemistry->reconcileReference(string);
Description:
	Parses the input reference and translates to class, id, and type
=cut
sub reconcileReference {
	my ($self,$ref) = @_;
	my $output;
	if ($ref =~ m/^([a-zA-z]+)\/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/) {
		$output->{class} = $1;
		$output->{id} = $2;
		$output->{type} = "uuid";
	} elsif ($ref =~ m/^([a-zA-z]+)\/([^\/]+)\/([^\/]+)/) {
		$output->{class} = $1;
		$output->{type} = $2;
		$output->{id} = $3;
	}
	return $output;
}

__PACKAGE__->meta->make_immutable;
