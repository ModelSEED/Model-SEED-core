

#!/usr/bin/perl -w

########################################################################
# Driver module that holds all functions that govern user interaction with the Model SEED
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 9/6/2011
########################################################################

use strict;
use lib "../../config/";
use ModelSEEDbootstrap;
use ModelSEED::utilities;
use ModelSEED::FIGMODEL;
use ModelSEED::CoreApi;
use ModelSEED::MS::ObjectManager;
use ModelSEED::MS::Environment;
use ModelSEED::MS::Factories::PPOFactory;
use File::Basename qw(dirname basename);

package ModelSEED::ModelDriverV2;

=head3 new
Definition:
	driver = driver->new();
Description:
	Returns a driver object
=cut
sub new { 
	my ($class,$args) = @_;
	ModelSEED::utilities::ARGS($args,["environment"],{
		finishfile => undef
	});
	$self->environment(ModelSEED::MS::Environment->new($args->{environment});
	$self->figmodel(ModelSEED::FIGMODEL->new({username => ModelSEED::Interface::interface::USERNAME(),password => ModelSEED::Interface::interface::PASSWORD()}));
	$self->om(ModelSEED::MS::ObjectManager->new({
		db => ModelSEED::FileDB->new({filename => $self->environment()->filedb()}),
		username => $self->environment()->username(),
		password => $self->environment()->password(),
		selectedAliases => $self->environment()->selectedAliases()
	}));
	my $self = {};
	bless $self;
	$self->finishfile($args->{finishfile});
    return $self;
}
=head3 figmodel
Definition:
	FIGMODEL = ModelDriverV2->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self,$figmodel) = @_;
	if (defined($figmodel)) {
		$self->{_figmodel} = $figmodel;
	}
	return $self->{_figmodel};
}
=head3 environment
Definition:
	ModelSEED::MS::Environment = ModelDriverV2->environment();
Description:
	Returns an Environment object
=cut
sub environment {
	my ($self,$environment) = @_;
	if (defined($environment)) {
		$self->{_environment} = $environment;
	}
	return $self->{_environment};
}
=head3 om
Definition:
	ModelSEED::MS::ObjectManager = driver->om();
Description:
	Returns an ObjectManager object
=cut
sub om {
	my ($self,$om) = @_;
	if (defined($om)) {
		$self->{_om} = $om;
	}
	return $self->{_om};
}
=head3 db
Definition:
	FIGMODEL = driver->db();
Description:
	Returns a database object
=cut
sub db {
	my ($self) = @_;
	return $self->figmodel()->database();
}
=head3 config
Definition:
	{}/[] = driver->config(string);
Description:
	Returns a requested configuration object
=cut
sub config {
	my ($self,$key) = @_;
	return $self->figmodel()->config($key);
}
=head3 check
Definition:
	FIGMODEL = driver->check([string]:expected data,(string):supplied arguments);
Description:
	Check for sufficient arguments
=cut
sub check {
	my ($self,$array,$data) = @_;
	my @calldata = caller(1);
	my @temp = split(/:/,$calldata[3]);
    my $function = pop(@temp);
	if (!defined($data) || @{$data} == 0 || ($data->[0] eq $function && ref($data->[1]) eq "HASH" && keys(%{$data->[1]}) == 0)) {
		print $self->usage($function,$array);
		$self->finish("USAGE PRINTED");
	}
	my $args;
	if (defined($data->[1]) && ref($data->[1]) eq 'HASH') {
		$args = $data->[1];
		delete $data->[1];
	}
	if (defined($args->{"usage"}) || defined($args->{"help"}) || defined($args->{"man"})) {
		print STDERR $self->usage($function,$array);
	}
	for (my $i=0; $i < @{$array}; $i++) {
		if (!defined($args->{$array->[$i]->[0]})) {
			if ($array->[$i]->[1] == 1 && (!defined($data->[$i+1]) || length($data->[$i+1]) == 0)) {
				my $message = "Mandatory argument '".$array->[$i]->[0]."' missing!\n";
				$message .= $self->usage($function,$array);
				print STDERR $message;
				$self->finish($message);
			} elsif ($array->[$i]->[1] == 0 && (!defined($data->[$i+1]) || length($data->[$i+1]) == 0)) {
				$data->[$i+1] = $array->[$i]->[2];
			}
			$args->{$array->[$i]->[0]} = $data->[$i+1];
		}
	}
	return $args;
}
=head3 usage
Definition:
	FIGMODEL = driver->usage(string:function name,[string]:expected data);
Description:
	Prints the usage for the specified function
=cut
sub usage {
	my ($self,$function,$array) = @_;
	if (!defined($array)) {
		$self->$function();
		return undef;
	}
	my $output;
	if ($self->isCommandLineFunction($function) == 0) {
		$output = $function." is not a valid ModelSEED function!\n";
	} else {
		$output = $function." function usage:\n./".$function." ";
	 	for (my $i=0; $i < @{$array}; $i++) {
			if ($i > 0) {
				$output .= "?";
			}
			$output .= $array->[$i]->[0];
			if ($array->[$i]->[1] == 0) {
				if (!defined($array->[$i]->[2])) {
					$output .= "(undef)";
				} else {
					$output .= "(".$array->[$i]->[2].")";
				}
	 		}
	 	}
	 	$output .= "\n";
	}
	return $output;
}
=head3 ws
Definition:
	FIGMODEL = driver->ws();
Description:
	Returns a workspace object
=cut
sub ws {
	my ($self) = @_;
	return ModelSEED::Interface::interface::WORKSPACE();
}


=head3 finishfile
Definition:
	string = driver->finishfile(string:input filename);
Description:
	Getter setter for finish file
=cut
sub finishfile {
	my ($self,$input) = @_;
	if (defined($input)) {
		$self->{_finishedfile} = $input;
	}
	if (!defined($self->{_finishedfile})) {
		$self->{_finishedfile} = "NONE";	
	}
	return $self->{_finishedfile};
}
=head3 isCommandLineFunction
Definition:
	string = driver->isCommandLineFunction(string:input filename);
Description:
	Returns "1" if the input function is a ModelSEED interface function. Returns 0 otherwise.
=cut
sub isCommandLineFunction {
	my ($self,$infunction) = @_;
	if ($self->can($infunction)) {
		my $excluded = {
			finish=>1,outputdirectory=>1,makeArgumentHashFromCommand=>1,"new"=>1,finishfile=>1,usage=>1,check=>1,config=>1,db=>1,ws=>1,figmodel=>1
		};
		if (defined($excluded->{$infunction})) {
			return 0;
		}
		return 1;
	}
	return 0;
}
=head3 finish
Definition:
	FIGMODEL = driver->finish(string:message);
Description:
	Closes out the ModelDriver with the specified message
=cut
sub finish {
	my ($self,$message) = @_;
	if ($self->finishfile() ne "NONE") {
	    if ($self->{_finishedfile} =~ m/^\//) {
	        ModelSEED::utilities::PRINTFILE($self->finishfile(),[$message]);
	    } else {
	        ModelSEED::utilities::PRINTFILE($self->figmodel()->config("database message file directory")->[0].$self->finishfile(),[$message]);
	    }
	}
	exit();
}
=head3 outputdirectory
Definition:
	FIGMODEL = driver->outputdirectory();
Description:
	Returns the directory where output should be printed
=cut
sub outputdirectory {
	my ($self) = @_;
	return $self->{_outputdirectory};
}
=head3 dbtransfermain
Definition:
	driver->dbtransfermain();
Description:
	Transfers the main biochemistry and mapping objects to the new scheme, saves, and sets as the primary biochemistry and mapping.
=cut
sub dbtransfermain {
	my($self,@Data) = @_;
	my $args = $self->check([],[@Data],"transfers biochemistry and mapping to new scheme");
	my $ppofactory = ModelSEED::MS::Factories::PPOFactory->new({
		username => ModelSEED::Interface::interface::USERNAME(),
		password => ModelSEED::Interface::interface::PASSWORD()	
	});
	my $bio = $ppofactory->createBiochemistry();
	$bio->save($self->om());
	print "Saved biochemistry with uuid ".$bio->uuid()."\n"
	$self->environment()->biochemistry($bio->uuid());
	my $map = $ppofactory->createMapping({
		biochemistry => $bio,	
	});
	$map->save($self->om());
	print "Saved mapping with uuid ".$map->uuid()."\n"
	$self->environment()->mapping($bio->uuid());
	$self->environment()->save();
    return {success => 1,message => "Successfully imported mapping and biochemistry!"};
}
=head3 testobj
Definition:
	 = driver->testobj;
Description:
	Prints test objects
=cut
sub testobj {
	my($self,@Data) = @_;
	my $om = ModelSEED::MS::ObjectManager->new({
		db => ModelSEED::FileDB->new({filename => "C:/Code/Model-SEED-core/data/filedb/"}),
		username =>  ModelSEED::Interface::interface::USERNAME(),
		password => ModelSEED::Interface::interface::PASSWORD(),
		selectedAliases => {
			ReactionAliasSet => "ModelSEED",
			CompoundAliasSet => "ModelSEED",
			ComplexAliasSet => "ModelSEED",
			RoleAliasSet => "ModelSEED",
			RolesetAliasSet => "ModelSEED"
		}
	});
	$om->authenticate(ModelSEED::Interface::interface::USERNAME(),ModelSEED::Interface::interface::PASSWORD());
	my $biochemistry = $om->create("Biochemistry",{
		name=>"chenry/TestBiochem",
		public => 1,
		locked => 0
	});
	my $c = $biochemistry->create("Compartment",{
		locked => "0",
		id => "c",
		name => "c",
		hierarchy => 0
	});
	my $e = $biochemistry->create("Compartment",{
		locked => "0",
		id => "e",
		name => "e",
		hierarchy => 1
	});
	my $cpdA = $biochemistry->create("Compound",{
		locked => "0",
		name => "A",
		abbreviation => "A",
		unchargedFormula => "C",
		formula => "C",
		mass => 12,
		defaultCharge => 0,
		deltaG => 0,
		deltaGErr => 0
	});
	my $cpdB = $biochemistry->create("Compound",{
		locked => "0",
		name => "B",
		abbreviation => "B",
		unchargedFormula => "C",
		formula => "C",
		mass => 12,
		defaultCharge => 0,
		deltaG => 0,
		deltaGErr => 0
	});
	my $cpdC = $biochemistry->create("Compound",{
		locked => "0",
		name => "Biomass",
		abbreviation => "Biomass",
		unchargedFormula => "C",
		formula => "C",
		mass => 12,
		defaultCharge => 0,
		deltaG => 0,
		deltaGErr => 0
	});
	my $rxnA =  $biochemistry->create("Reaction",{
		locked => "0",
		name => "rxnA",
		abbreviation => "rxnA",
		reversibility => "=",
		thermoReversibility => "=",
		defaultProtons => 0,
		deltaG => 0,
		deltaGErr => 0,
		status => "Balanced",
	});
	my $inst = $rxnA->loadFromEquation({
		equation => "A[e] => A",
		aliasType => "name"
	});
	$biochemistry->add("ReactionInstance",$inst);
	print "Equation:".$rxnA->definition()."\n";
	my $rxnB =  $biochemistry->create("Reaction",{
		locked => "0",
		name => "rxnB",
		abbreviation => "rxnB",
		reversibility => ">",
		thermoReversibility => ">",
		defaultProtons => 0,
		deltaG => 0,
		deltaGErr => 0,
		status => "Balanced",
	});
	$inst = $rxnB->loadFromEquation({
		equation => "A => B",
		aliasType => "name"
	});
	$biochemistry->add("ReactionInstance",$inst);
	my $media = $biochemistry->create("Media",{
		locked => "0",
		id => "MediaA",
		name => "MediaA",
		isDefined => 1,
		isMinimal => 1,
		type => "Test"
	});
	$media->create("MediaCompound",{
		compound_uuid => $cpdA->uuid(),
		concentration => 0.001,
		maxFlux => 100,
		minFlux => -100,
	});
	my $mapping = $om->create("Mapping",{name=>"chenry/TestMapping"});
	my $annoation = $om->create("Annotation",{});
	my $model = $om->create("Model",{
		locked => 0,
		public => 1,
		id => "TestModel",
		name => "TestModel",
		version => 1,
		type => "Singlegenome",
		status => "Model loaded",
		reactions => 2,
		compounds => 3,
		annotations => 2,
		growth => 1,
		current => 1,
		mapping_uuid => $mapping->uuid(),
		biochemistry_uuid => $biochemistry->uuid(),
		annotation_uuid => $annoation->uuid(),
	});
	my $mdlcompC = $model->create("ModelCompartment",{
		locked => 0,
		compartment_uuid => $c->uuid(),
		compartmentIndex => 0,
		label => "c0",
		pH => 7,
		potential => 1
	});
	my $mdlcompE = $model->create("ModelCompartment",{
		locked => 0,
		compartment_uuid => $e->uuid(),
		compartmentIndex => 0,
		label => "e0",
		pH => 7.5,
		potential => 1
	});
	my $mdlcpdAE = $model->create("ModelCompound",{
		compound_uuid => $cpdA->uuid(),
		charge => 0,
		formula => "C",
		model_compartment_uuid => $mdlcompE->uuid()
	});
	my $mdlcpdAC = $model->create("ModelCompound",{
		compound_uuid => $cpdA->uuid(),
		charge => 0,
		formula => "C",
		model_compartment_uuid => $mdlcompC->uuid()
	});
	my $mdlcpdBC = $model->create("ModelCompound",{
		compound_uuid => $cpdB->uuid(),
		charge => 0,
		formula => "C",
		model_compartment_uuid => $mdlcompC->uuid()
	});
	my $mdlcpdCC = $model->create("ModelCompound",{
		compound_uuid => $cpdC->uuid(),
		charge => 0,
		formula => "C",
		model_compartment_uuid => $mdlcompC->uuid()
	});
	my $mdlrxnA = $model->create("ModelReaction",{
		reaction_uuid => $rxnA->uuid(),
		direction => "=",
		protons => 0,
		model_compartment_uuid => $mdlcompC->uuid()
	});
	$mdlrxnA->create("ModelReactionRawGPR",{
		isCustomGPR => 1,
		rawGPR => "b0001"
	});
	$mdlrxnA->create("ModelReactionTransports",{
		modelcompound_uuid => $mdlcpdAE->uuid(),
		compartmentIndex => 1,
		coefficient => -1
	});
	my $mdlrxnB = $model->create("ModelReaction",{
		reaction_uuid => $rxnB->uuid(),
		direction => "=",
		protons => 0,
		model_compartment_uuid => $mdlcompC->uuid()
	});
	$mdlrxnB->create("ModelReactionRawGPR",{
		isCustomGPR => 1,
		rawGPR => "b0002"
	});
	my $biomass = $model->create("Biomass",{
		locked => 0,
		name => "Biomass"
	});
	$biomass->create("BiomassCompound",{
		modelcompound_uuid => $mdlcpdBC->uuid(),
		coefficient => -1
	});
	$biomass->create("BiomassCompound",{
		modelcompound_uuid => $mdlcpdCC->uuid(),
		coefficient => 1
	});
	ModelSEED::utilities::PRINTFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/MediaA.media.json",[JSON::Any->encode($media->serializeToDB())]);
	ModelSEED::utilities::PRINTFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/cpdA.compound.json",[JSON::Any->encode($cpdA->serializeToDB())]);
	ModelSEED::utilities::PRINTFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/Test.biochem.json",[JSON::Any->encode($biochemistry->serializeToDB())]);
	ModelSEED::utilities::PRINTFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/rxnA.reaction.json",[JSON::Any->encode($rxnA->serializeToDB())]);
	ModelSEED::utilities::PRINTFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/TestModel.model.json",[JSON::Any->encode($model->serializeToDB())]);
	ModelSEED::utilities::PRINTFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/Biomass.biomass.json",[JSON::Any->encode($biomass->serializeToDB())]);
	return {success => 1};
}
=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function lists the types of biochemistry objects
=EXAMPLE
bc-listtypes
=cut
sub bclisttypes {
    my($self,@Data) = @_;
	my $args = $self->check([],[@Data],"lists the types of biochemistry objects");
    return {success => 1,message => "Biochemistry types:\n".join("\n",@{[
    	"media",
    	"reaction",
    	"compound",
    	"compoundset",
    	"reactionset"
    ]})};
}
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function prints a table of objects from the biochemistry database
=EXAMPLE
bc-list media
=cut
sub bclist {
    my($self,@Data) = @_;
	my $args = $self->check([
		["type",1,undef,"type of the object to be printed"],
	],[@Data],"prints a table of objects from the biochemistry");
    $self->biochemistry()->checkType($args->{type});
    my $tbl = $self->biochemistry()->printTable($args->{type});
    my $rows;
    for (my $i=0; $i < @{$tbl->{rows}};$i++) {
    	push(@{$rows},join("\t",@{$tbl->{rows}->[$i]}));
    }
    return {success => 1,message =>
    	"Biochemistry ".$args->{type}." objects:\n".
    	join("\t",@{$tbl->{headings}})."\n".
    	join("\n",@{$rows})
    };
}
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function prints a file with object data to the workspace
=EXAMPLE
bc-print media "Carbon-D-Glucose"
=cut
sub bcprint {
    my($self,@Data) = @_;
	my $args = $self->check([
		["type",1,undef,"type of the object to be printed"],
		["id",1,undef,"id of object to be printed"]
	],[@Data],"prints a file with object data to the workspace");
    my $obj = $self->biochemistry()->getObject({type=>$args->{type},query=>{id=>$args->{id}}});
    if (!defined($obj)) {
    	ModelSEED::utilities::USEERROR("No object of type ".$args->{type}." and with id ".$args->{id}." found in biochemistry ".$self->biochemistry()->uuid()."!");
    }
    $obj->printToFile({filename=>$self->ws()->directory().$args->{id}.".".$args->{type}});
    return {success => 1,message => "Object successfully printed to file ".$args->{id}.".".$args->{type}." in workspace!"};
}
=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used to create or alter a media condition in the Model SEED database given either a list of compounds in the media or a file specifying the media compounds and minimum and maximum uptake rates.
=EXAMPLE
bcloadmedia '''-name''' Carbon-D-Glucose '''-filename''' Carbon-D-Glucose.txt
=cut
sub bcload {
    my($self,@Data) = @_;
	my $args = $self->check([
		["type",1,undef,"type of the object to be loaded"],
		["id",1,undef,"id of the object to be loaded"],
		["overwrite",0,0,"overwrite the existing object?"]
	],[@Data],"Creates (or alters) an object in the Model SEED database");
	my $obj = $self->biochemistry()->getObject({type=>$args->{type},query=>{id=>$args->{id}}});
	if (defined($obj) && $args->{overwrite} == 0) {
		ModelSEED::utilities::USEERROR("Object of type ".$args->{type}." with id ".$args->{id}." already exists in biochemistry ".$self->biochemistry()->uuid().". Must set overwrite flag to load object!");
	}
	my $data = ModelSEED::MS::ObjectParser::loadObjectFile({type => $args->{type},id => $args->{id},directory => $self->ws()->directory()});
	my $newObj = ModelSEED::MS::Media->new({biochemistry => $self->biochemistry(),attributes => $data->{attributes},relationships => $data->{relationships}});
	$self->biochemistry()->add($newObj);
	my $time = time();
	print "Saving!\n";
	$self->biochemistry()->save();
	print "Save time:".$time-time()."\n";
	return {success => 1,message => "Successfully loaded ".$args->{type}." object from file with id ".$args->{id}."."};
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to print a specified model to a file in the workspace
=EXAMPLE
mdlprint Seed83333.1
=cut
sub mdlprint {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"type of the object to be loaded"]
	],[@Data],"Creates (or alters) an object in the Model SEED database");
	my $model = $self->getModel($args->{model});
	if (!defined($model)) {
		ModelSEED::utilities::USEERROR("No model found with id ".$args->{model}."!");	
	}
	$model->printToFile({filename=>$self->ws()->directory().$args->{model}.".model"});
	return {success => 1,message => "Successfully printed model ".$args->{model}." to file ".$self->ws()->directory().$args->{model}.".model in the workspace."};
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to print a specified model to a file in the workspace
=EXAMPLE
mdlprint Seed83333.1
=cut
sub mdlpricereconstruction {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"type of the object to be loaded"],
	],[@Data],"Creates (or alters) an object in the Model SEED database");
	my $model = $self->getModel($args->{model});
	$model->priceReconstruction($args);
	$model->printToFile({filename=>$self->ws()->directory().$args->{model}.".model"});
	return {success => 1,message => "Successfully printed model ".$args->{model}." to file ".$self->ws()->directory().$args->{model}.".model in the workspace."};
}
=head
=CATEGORY
Mapping Operations
=DESCRIPTION
This function is used to print a specified mapping object
=EXAMPLE
mapprint
=cut
sub mapprint {
    my($self,@Data) = @_;
	my $args = $self->check([
		["mapping",1,undef,"ID of a mapping object"]
	],[@Data],"Prints the specified mapping object");
	my $mapping = $self->getMapping($args->{mapping});
	if (!defined($mapping)) {
		ModelSEED::utilities::USEERROR("No mapping found with uuid ".$args->{mapping}."!");	
	}
	$mapping->printToFile({filename=>$self->ws()->directory().$args->{mapping}.".mapping"});
	return {success => 1,message => "Successfully printed mapping ".$args->{mapping}." to file ".$self->ws()->directory().$args->{mapping}.".mapping in the workspace."};
}

1;
