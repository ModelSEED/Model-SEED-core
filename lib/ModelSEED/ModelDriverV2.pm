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
use Class::Autouse qw(
    ModelSEED::FIGMODEL
    ModelSEED::Configuration
    ModelSEED::Store
    ModelSEED::Auth::Basic
);
use ModelSEED::Database::FileDB;
use ModelSEED::Store::Private;
use ModelSEED::MS::Factories::PPOFactory;
use ModelSEEDbootstrap;
use ModelSEED::utilities;
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
	ModelSEED::utilities::ARGS($args,[],{
		environment => {},
		finishfile => undef
	});
	my $self = {};
	bless $self;
    $self->config(ModelSEED::Configuration->new());
    $self->environment($self->config->config);
    my $c = $self->config->config;
	$self->figmodel(ModelSEED::FIGMODEL->new({
        username => $c->{login}->{username},
        password => $c->{login}->{password},
    }));
    my $auth = ModelSEED::Auth::Basic->new(
        username => $c->{login}->{username},
        password => $c->{login}->{password},
    );
    $self->om(ModelSEED::Store->new( auth => $auth ));
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
	ModelSEED::MS:: = ModelDriverV2->environment();
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
=head3 store
Definition:
	ModelSEED::Store = driver->store();
Description:
    Returns a ModelSEED::Store object
=cut
sub store {
	my ($self,$store) = @_;
	if (defined($store)) {
		$self->{_store} = $store;
	}
	return $self->{_store};
}
=head3 loadObjectFromJSONFile
Definition:
	ModelSEED::MS::$type = driver->loadObjectFromJSONFile();
Description:
	Loads the object of specified type from the specified JSON file
=cut
sub loadObjectFromJSONFile {
	my ($self, $type, $filename) = @_;
	#$filename = "c:/Code/Model-SEED-core/data/exampleObjects/FullMapping.json";
	my $class = "ModelSEED::MS::".$type;
	print "test1\t".$filename."\n";
	open FILE, "<".$filename;
	my $string = <FILE>;
	print "Done!";
	exit();
	my $objectData = JSON::Any->decode($string);
	close TEMPFILE;
	print "test3\n";
	return $class->new($objectData);	
}
=head3 biochemistry
Definition:
	ModelSEED::MS::Biochemistry = driver->biochemistry();
Description:
	Returns an biochemistry object
=cut
sub biochemistry {
	my ($self) = @_;
    my $wanted = $self->environment()->{biochemistry};
    my $got = $self->{_biochemistry};
    if (!defined($got) || $got->uuid ne $wanted) {
        $self->{_biochemistry} = $self->om()->get_object("biochemistry/$wanted");
    }
	return $self->{_biochemistry};
}
=head3 mapping
Definition:
	ModelSEED::MS::Mapping = driver->mapping();
Description:
	Returns an mapping object
=cut
sub mapping {
	my ($self) = @_;
    my $wanted = $self->environment()->{mapping};
    my $got = $self->{_mapping};
    if (!defined($got) || $got->uuid ne $wanted) {
        $self->{_mapping} = $self->om()->get_object("mapping/$wanted");
    }
	return $self->{_mapping};
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
	my ($self,$val) = @_;
    if($val) {
        $self->{_config} = $val;
    }
    return $self->{_config};
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
=head3 mslasterror
Definition:
	driver->mslasterror();
Description:
	This function prints the last error file to screen, as well as printing filename.
=cut
sub mslasterror {
    my ($self, @Data) = @_;
    my $args = $self->check([],[@Data],"print last error");
    my $errorFile = $self->environment()->{lasterror};
	if ( $errorFile eq "NONE" || !-e $errorFile) {
		return "Last error file not found!";
	}
	my $output = ["Last error printed to file:","",$errorFile,"","Error text printed below:"];
	push(@{$output},@{ModelSEED::utilities::LOADFILE($errorFile)});
    return {success => 1,message => join("\n",@{$output})};
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
    my $username = $self->environment()->{login}->{username};
	my $ppofactory = ModelSEED::MS::Factories::PPOFactory->new({
		om => $self->store(),
		username => $self->environment()->{login}->{username},
		password => $self->environment()->{login}->{password}	
	});
	my $bio = $ppofactory->createBiochemistry();
    my $bioAlias = "$username/bio-main";
    my $mapAlias = "$username/map-main";

	$bio->save($bioAlias);
	$bio->printJSONFile(ModelSEED::utilities::MODELSEEDCORE()."/data/exampleObjects/FullBiochemistry.json");
	print "Saved biochemistry with alias '$bioAlias'\n";
	$self->environment()->{biochemistry} = $bioAlias;
	my $map = $ppofactory->createMapping({
		biochemistry => $bio,	
	});
	$map->save($mapAlias);
	$map->printJSONFile(ModelSEED::utilities::MODELSEEDCORE()."/data/exampleObjects/FullMapping.json");
	print "Saved mapping with alias '$mapAlias'\n";
	$self->environment()->{mapping} = $mapAlias;
	$self->config()->save();
    return {success => 1,message => "Successfully imported mapping and biochemistry!"};
}
=head3 dbtransfermodel
Definition:
	driver->dbtransfermodel();
Description:
	Transfers a selected model (or all models) to the new scheme
=cut
sub dbtransfermodel {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"model to be transfered"]
	],[@Data],"transfers model to new scheme");
    my $username = $self->environment()->{login}->{username};
	my $ppofactory = ModelSEED::MS::Factories::PPOFactory->new({
		om => $self->store(),
		username => "chenry",
		password => "Ko3BA9yMnMj2k"
	});
	print "Loading biochemistry!\n";
	#my $biochemistry = $self->biochemistry();
	my $biochemistry = $self->loadObjectFromJSONFile("Biochemistry",ModelSEED::utilities::MODELSEEDCORE()."/data/exampleObjects/FullBiochemistry.json");
	print "Loading mapping!\n";
	#my $mapping = $self->mapping();
	my $mapping = $self->loadObjectFromJSONFile("Mapping",ModelSEED::utilities::MODELSEEDCORE()."/data/exampleObjects/FullMapping.json");
	print "Transfering model!\n";
	my $model = $ppofactory->createModel({
		model => $args->{model},
		biochemistry => $self->biochemistry(),
		mapping => $self->mapping()
	});
    my $modelAlias = "$username/mdl-".$args->{model};
    $modelAlias =~ s/\./-/g;
	$model->save($modelAlias);
	print "Saved model with alias '$modelAlias'\n";
	$model->printJSONFile(ModelSEED::utilities::MODELSEEDCORE()."/data/exampleObjects/FullModel.json");
    return {success => 1,message => "Successfully imported model!"};
}
=head3 testobj
Definition:
	 = driver->testobj;
Description:
	Prints test objects
=cut
sub testobj {
	my($self,@Data) = @_;
    my $om = ModelSEED::Store->new({
		username => $self->environment()->{login}->{username},
		password => $self->environment()->{login}->{password},
    });
=cut
	my $om = ModelSEED::MS::ObjectManager->new({
		db => ModelSEED::FileDB->new({directory => "C:/Code/Model-SEED-core/data/filedb/"}),
		selectedAliases => {
			ReactionAliasSet => "ModelSEED",
			CompoundAliasSet => "ModelSEED",
			ComplexAliasSet => "ModelSEED",
			RoleAliasSet => "ModelSEED",
			RoleSetAliasSet => "ModelSEED"
		}
	});
=cut
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
	my $instA = $rxnA->loadFromEquation({
		equation => "A[e] => A",
		aliasType => "name"
	});
	$biochemistry->add("ReactionInstance",$instA);
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
	my $instB = $rxnB->loadFromEquation({
		equation => "A => B",
		aliasType => "name"
	});
	$biochemistry->add("ReactionInstance",$instB);
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
		modelcompartment_uuid => $mdlcompE->uuid()
	});
	my $mdlcpdAC = $model->create("ModelCompound",{
		compound_uuid => $cpdA->uuid(),
		charge => 0,
		formula => "C",
		modelcompartment_uuid => $mdlcompC->uuid()
	});
	my $mdlcpdBC = $model->create("ModelCompound",{
		compound_uuid => $cpdB->uuid(),
		charge => 0,
		formula => "C",
		modelcompartment_uuid => $mdlcompC->uuid()
	});
	my $mdlcpdCC = $model->create("ModelCompound",{
		compound_uuid => $cpdC->uuid(),
		charge => 0,
		formula => "C",
		modelcompartment_uuid => $mdlcompC->uuid()
	});
	$model->addReactionInstanceToModel({
		reactionInstance => $instA,
		direction => "=",
		protons => 0,
		gpr => "(b0001 and b0002)",
	});
	$model->addReactionInstanceToModel({
		reactionInstance => $instB,
		direction => "=",
		protons => 0,
		gpr => "(b0003 and b0004)",
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
	$media->printJSONFile($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/MediaA.media.json");
	$cpdA->printJSONFile($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/cpdA.compound.json");
	$biochemistry->printJSONFile($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/Test.biochem.json");
	$rxnA->printJSONFile($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/rxnA.reaction.json");
	$model->printJSONFile($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/TestModel.model.json");
	$biomass->printJSONFile($ENV{MODEL_SEED_CORE}."/data/ReactionDB/Examples/Biomass.biomass.json");
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
