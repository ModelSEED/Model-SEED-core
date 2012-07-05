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
#use ModelSEED::Store;
package ModelSEED::MS::Factories::ExchangeFormatFactory;
use Moose;
use namespace::autoclean;
#***********************************************************************************************************
# ATTRIBUTES:
#***********************************************************************************************************
has store => ( is => 'rw', isa => 'ModelSEED::Store', lazy => 1, builder => '_buildstore' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildstore {
	my ($self) = @_;
	return ModelSEED::Store->new();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 buildFBAFormulationFromExchange
Definition:
	ModelSEED::MS::FBAFormulation = ModelSEED::MS::Biochemistry->buildFBAFormulationFromExchange({
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
		name => "Default",
		media => "Media/name/Complete",
		type => "singlegrowth",
		description => "None provided",
		growthConstraint => "none",
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
		defaultMaxDrainFlux => 100,
		defaultMinDrainFlux => -100,
		maximizeObjective => 1,
		decomposeReversibleFlux => 0,
		decomposeReversibleDrainFlux => 0,
		fluxUseVariables => 0,
		drainfluxUseVariables => 0,
		fbaConstraints => [],
		fbaObjectiveTerms => [{
			variableType => "biomassflux",
			id => "Biomass/name/bio1",
			coefficient => 1
		}]
	});
	#Translating constraints
	my $vartrans = {
		f => "flux",ff => "forflux",rf => "revflux",
		df => "drainflux",fdf => "fordrainflux",rdf => "revdrainflux",
		ffu => "forfluxuse",rfu => "reffluxuse"
	};
	for (my $i=0; $i < @{$data->{fbaConstraints}};$i++) {
		my $array = [split(/\+/,$data->{fbaConstraints}->[$i]->{terms})];
		my $terms;
		for (my $j=0; $j < @{$array};$j++) {
			if ($array->[$j] =~ /\((\d+\.*\d*)\)(\w+)_([\w\/]+)\[(w+)\]/) {
				my $coef = $1;
				my $vartype = $vartrans->{$2};
				my $refarray = [split(/\//,$3)];
				my $type = $refarray->[0];
				my $obj;
				if ($type eq "Compound") {
					$obj = $model->queryObject("modelcompounds",{$refarray->[1] => $refarray->[2]});
				} elsif ($type eq "Reaction") {
					$obj = $model->queryObject("modelreactions",{$refarray->[1] => $refarray->[2]});
				} elsif ($type eq "Biomass") {
					$obj = $model->biomasses()->[0];
				}
				push(@{$terms},{
					entity_uuid => $obj->uuid(),
					entityType => $type,
					variableType => $vartype,
					coefficient => $coef
				});
			}
		}
		$data->{fbaConstraints}->[$i] = {
			name => $data->{fbaConstraints}->[$i]->{name},
			rhs => $data->{fbaConstraints}->[$i]->{rhs},
			sign => $data->{fbaConstraints}->[$i]->{sign},
			fbaConstraintVariables => $terms
		};
	}
	#Translating objective terms
	for (my $i=0; $i < @{$data->{fbaObjectiveTerms}};$i++) {
		my $array = [split(/\//,$data->{fbaObjectiveTerms}->[$i]->{id})];
		my $type = $array->[0];
		my $obj;
		if ($type eq "Compound") {
			$obj = $model->queryObject("modelcompounds",{$array->[1] => $array->[2]});
		} elsif ($type eq "Reaction") {
			$obj = $model->queryObject("modelreactions",{$array->[1] => $array->[2]});
		} elsif ($type eq "Biomass") {
			$obj = $model->biomasses()->[0];
		}
		if (defined($obj)) {
			$data->{fbaObjectiveTerms}->[$i] = {
				coefficient => $data->{fbaObjectiveTerms}->[$i]->{coefficient},
				variableType => $data->{fbaObjectiveTerms}->[$i]->{variableType},
				entityType => $type,
				entity_uuid => $obj->uuid(),
			};
		}
	}
	#Finding (or creating) the media
	my $media;
	my $array = [split(/\//,$data->{media})];
	if (!defined($array->[2]) || $array->[0] ne "Media") {
		ModelSEED::utilities::ERROR("Bad media reference in exchange format: ".$data->{media});
	}
	if ($array->[1] eq "uuid" || $array->[1] eq "name" || $array->[1] eq "id") {
		$media = $model->biochemistry()->queryObject("media",{$array->[1] => $array->[2]});
	} elsif ($array->[1] eq "compounds") {
		
	} else {
		$media = $model->biochemistry()->getObjectByAlias("media",$array->[2],$array->[1]);		
	}
	if (!defined($media)) {
		ModelSEED::utilities::ERROR("Media referenced in formulation not found in database: ".$data->{media});
	}
	#Parsing uptake limits
	my $uptakeLim = {};
	if ($data->{uptakeLimits} ne "none") {
		my $array = [split(/\|/,$data->{uptakeLimits})];
		foreach my $item (@{$array}) {
			my $subarray = [split(/\:/,$item)];
			if (defined($subarray->[1])) {
				$uptakeLim->{$subarray->[0]} = $subarray->[1];
			}
		}
	}
	print STDERR Data::Dumper->Dump([$data]);
	#Creating objects and populating with provenance objects
	my $form = ModelSEED::MS::FBAFormulation->new({
		name => $data->{name},
		model_uuid => $model->uuid(),
		media_uuid => $media->uuid(),
		biochemistry_uuid => $model->biochemistry()->uuid(),
		type => $data->{type},
		description => $data->{description},
		growthConstraint => $data->{growthConstraint},
		thermodynamicConstraints => $data->{thermodynamicConstraints},
		allReversible => $data->{allReversible},
		dilutionConstraints => $data->{allReversible},
		uptakeLimits => $uptakeLim,
		geneKO => [split(/\|/,$data->{geneKO})],
		defaultMaxFlux => $data->{defaultMaxFlux},
		defaultMaxDrainFlux => $data->{defaultMaxDrainFlux},
		defaultMinDrainFlux => $data->{defaultMinDrainFlux},
		maximizeObjective => $data->{maximizeObjective},
		decomposeReversibleFlux => $data->{decomposeReversibleFlux},
		decomposeReversibleDrainFlux => $data->{decomposeReversibleDrainFlux},
		fluxUseVariables => $data->{fluxUseVariables},
		drainfluxUseVariables => $data->{drainfluxUseVariables},
		fbaObjectiveTerms => $data->{fbaObjectiveTerms},
		fbaConstraints => $data->{fbaConstraints}
	});
	$form->media($media);
	$form->model($model);
	$form->biochemistry($model->biochemistry());
	return $form;
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
		array => []
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
