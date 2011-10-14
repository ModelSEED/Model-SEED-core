use strict;
package ModelSEED::FIGMODEL::FIGMODELmodel;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELmodel object
=head2 Introduction
Module for manipulating model objects.
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELmodel = FIGMODELmodel->new();
Description:
	This is the constructor for the FIGMODELmodel object.
	Arguments: 
		id, { new configuration }
		   
=cut
sub new {
	my ($class, $figmodel, $id, $args) = @_;
	if (!defined($figmodel)) {
		warn "FIGMODELmodel->new(undef,".$id."):".
			 "figmodel must be defined to create a model object!\n";
		return undef;
	}
	my $modelObj; # <== the ppo object
	my $self = {_id => $id, _fullId => $id, _figmodel => $figmodel};
	# weaken figmodel even though it should disappear quickly, replaced by a private figmodel
	Scalar::Util::weaken($self->{_figmodel});
	bless $self;
	if(defined($args) && ref($args) eq 'HASH') { # if we're constructing a new model
		my $isDebug	= $figmodel->config("Database version")->[0] eq "DevModelDB";
		my $default_id = "Seed".$args->{genome};
		my $user = $figmodel->database()->get_object("user",
			{login=>$args->{owner}}) if(defined($args->{owner}) && $args->{owner} ne "master");
		my $user_id;
		if(defined($user)) {
			$user_id = $user->_id();
			$default_id .= '.'.$user_id;
		}
		$args = $figmodel->process_arguments($args, ["genome"], {
			runPreliminaryReconstruction => 1,
			id => (defined($id)) ? $id : $default_id,
			gapfilling => 0,
			autocompleteMedia => "Complete",
			owner => "master",
			queue => $isDebug ? "development" : "fast",
			biochemSource => undef,
			biomassReaction => "NONE",
			cellwalltype => "Unknown",
			name => "Unknown",
			source => "Unknown",
		});
		# append userid if the user opted out of the "Seed"+"organism_id" setup
		if($args->{id} ne $default_id && $args->{owner} ne 'master') {
			if(!defined($user_id)) {
				ModelSEED::FIGMODEL::FIGMODELERROR("No valid user for ".$args->{owner}.", failed to create model!");
			} elsif($args->{id} !~ /\.$user_id$/) {
				$args->{id} .= '.'.$user_id; 
			}
			$self->{_fullId} = $args->{id};
		}
		# Determining if model is public
		my $public = 1;
		if($args->{owner} ne "master") {
			$public = 0;
		}
		#Checking to see if a model with the same ID doesnt already exist
		$modelObj = $figmodel->database()->get_object("model",{id => $args->{id}});
		ModelSEED::FIGMODEL::FIGMODELERROR("A model called ".$args->{id}." already exists.") if (defined($modelObj));
		#Adding model to the database
		$modelObj = $figmodel->database()->create_object("model",{  
			id => $args->{id},
			owner => $args->{owner},
			public => $public,
			genome => $args->{genome},
			source => $args->{source},
			modificationDate => time(),
			builtDate => time(),
			autocompleteDate => -1,
			status => -2,
			version => 0,
			message => "Model reconstruction queued",
			cellwalltype => $args->{cellwalltype},
			autoCompleteMedia => $args->{autocompleteMedia},
			biomassReaction => $args->{biomassReaction},
			growth => 0,
			name => $args->{name}
		});
		print "Adding new model ",$args->{id}," for ",$args->{owner}," into database\n";
		$self->ppo($modelObj);
		$self->create_model_rights();
		$self->GenerateModelProvenance({
			biochemSource => $args->{biochemSource}
		});
		if ($args->{runPreliminaryReconstruction} eq "1") {
			if ($args->{queue} eq "NONE") {
				$self->preliminary_reconstruction({
					runGapfilling => $args->{gapfilling},	
				});	
			} else {
				my $RunGapFilling = "";
				if ($args->{gapfilling} eq "1") {
					$RunGapFilling = "?1";
				}
				$self->figmodel()->add_job_to_queue({
					command => "preliminaryreconstruction?".$args->{id}.$RunGapFilling,
					queue => $args->{queue},
					user => $args->{owner}
				});
			}
		}
		$id = $args->{id};
	}
	my $id_parts = $self->parseId($self->fullId());  
	# if the model isn't the current version, the ppo is in model_version
	if (!defined($modelObj)) {
        $modelObj = $self->db()->get_object("model", {id => $args->{id}});
		if (!defined($modelObj)) {
		    $modelObj = $self->db()->get_object("model_version", { id => $id_parts->{full} });
		 	if (!defined($modelObj)) {
		 		$modelObj = $self->db()->get_object("model", {id => $id_parts->{canonical}});
		 	}
		}
        ModelSEED::FIGMODEL::FIGMODELERROR("Model not found!") if (!defined($modelObj));
		$self->ppo($modelObj);
	}
	# need to make a copy of this, otherwise we're actually MODIFYING parent FIGMODEL which is BAD
	my $configurationFiles = [@{$self->{_figmodel}->{_configSettings}}];
	# Build default configuration based on files in model->directory()
	push(@$configurationFiles, $self->build_default_model_config());
	# Find model directory and load configuration file .figmodel_config if it's there
	if(-f $self->directory().'.figmodel_config') {
		push(@$configurationFiles, $self->directory().'.figmodel_config');
	}
	# Rebuild FIGMODEL with new configuration
	my $model_figmodel = ModelSEED::FIGMODEL->new({ userObj => $figmodel->userObj(),
							configFiles => $configurationFiles,
						      });
	$self->{_figmodel} = $model_figmodel; # strong ref intentional
	ModelSEED::FIGMODEL::FIGMODELERROR("id must be defined to create a model object") if (!defined($id));
	# Here the model has the "strong" reference to figmodel, while
	# figmodel has the weak one to the model. So the figmodel will
	# stick around as long as the model stays around.
	$self->figmodel()->{_models}->{$self->fullId()} = $self; 
	Scalar::Util::weaken($self->figmodel()->{_models}->{$self->fullId()});
	return $self;
}

=head3 config
Definition:
	ref::key value = FIGMODELmodel->config(string::key);
Description:
	Trying to avoid using calls that assume configuration data is stored in a particular manner.
	Call this function to get file paths etc.
=cut
sub config {
	my ($self,$key) = @_;
	return $self->figmodel()->config($key);
}

=head3 error_message
Definition:
	{}:Output = FIGMODELmodel->new_error_message({
		function => "?",
		message => "",
		args => {}
	})
	Output = {
		error => string:error message,
		msg => string:error message,
		success => 0
	}
Description:
=cut
sub error_message {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		package => "FIGMODELmodel(".$self->id().")",
	});
	return $self->figmodel()->new_error_message($args);
}
=head3 debug_message
Definition:
	{}:Output = FIGMODELmodel->debug_message({
		function => "?",
		message => "",
		args => {}
	})
	Output = {
		error => "",
		msg => "",
		success => 0
	}
Description:
=cut
sub debug_message {
	my ($self,$args) = @_;
	$args = $self->figmodel()->debug_message($args,[],{
		package => "FIGMODELmodel(".$self->id().")",
	});
	return $self->figmodel()->debug_message($args);
}
sub globalMessage {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["msg"],{
		id => $self->id(),
	});
	$args->{callIndex} = 2;
	$self->figmodel()->globalMessage($args);
}
sub getCache {
	my ($self,$key) = @_;
	return $self->figmodel()->getCache({package=>"FIGMODELmodel",id=>$self->id(),key=>$key});
}
sub setCache {
	my ($self,$key,$data) = @_;
	return $self->figmodel()->setCache({package=>"FIGMODELmodel",id=>$self->id(),key=>$key,data=>$data});
}

=head3 aquireModelLock
Definition:
	FIGMODELmodel->aquireModelLock();
Description:
	Locks the database for alterations relating to the current model object
=cut
sub aquireModelLock {
	my ($self) = @_;
	$self->figmodel()->database()->genericLock($self->id());
}

=head3 releaseModelLock
Definition:
	FIGMODELmodel->releaseModelLock();
Description:
	Unlocks the database for alterations relating to the current model object
=cut
sub releaseModelLock {
	my ($self) = @_;
	$self->figmodel()->database()->genericUnlock($self->id());
}

=head3 delete
Definition:
	FIGMODEL = FIGMODELmodel->delete();
Description:
	Deletes the model object
=cut
sub delete {
	my ($self) = @_;
	my $directory = $self->directory();
	my $id = $self->id();
	if (length($id) > 0) {
		chomp($directory);
		print "Deleting directory ".$directory."\n"; 
		system("rm -rf ".$directory);
	}
	$self->figmodel()->database()->delete_object({type => "model",object => $self->ppo(),recursive => 1});
}

=head3 copyModel
Definition:
	FIGMODEL = FIGMODELmodel->copyModel({newid=>string});
Description:
	Copys the model to a new location and ID. If owner is not
	supplied, defaults to the model's current owner.
=cut
sub copyModel {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		newid=>undef,
		owner=> $self->owner(),
	});
	my $usrObj = $self->figmodel()->database()->get_object("user",{login=>$args->{owner}});
	if (!defined($args->{newid})) {
		my $index = 0;
		do {
	
			$args->{newid} = "Seed".$self->genome();
			if ($index != 0) {
				$args->{newid} .= "-".$index;
			}
			$args->{newid} .= ".".$usrObj->_id();
			$index++;		
		} while(defined($self->db()->get_object("model", { id => $args->{newid} }))); 
	}
	# TODO add validateID function, need to know passed user id is correct
	# append ".userId" if that hasn't already been done
	my $userId = $self->db()->get_object("user", { login => $args->{owner} })->_id();
	if($args->{newid} !~  /\.$userId$/) {
		$args->{newid} .= '.'.$userId;
	}
	if (defined($self->figmodel()->database()->get_object("model",{id=>$args->{newid}}))) {
		ModelSEED::FIGMODEL::FIGMODELERROR("A model with the suppied ID already exists");
	}
	# Create copy of biomass function
	my $biomass = $self->figmodel()->get_reaction($self->ppo()->biomassReaction());
	my $biomassCopy = $biomass->copyReaction({owner => $args->{owner}});
	# Copy directory structure
	my $new_model_dir = $self->config("model directory")->[0] . $args->{owner} . '/' . $args->{newid};
	if (-d $new_model_dir) {
		ModelSEED::FIGMODEL::FIGMODELERROR("Directory ".$new_model_dir." already exists for model ".$args->{newid});
	}
	my $current_model_dir = $self->directory();
	$current_model_dir =~ s/\d+\/$//; # remove trailing version number
	File::Copy::Recursive::dircopy($current_model_dir, $new_model_dir);   
	# Build initial model, use ppo to get most configuration details
	my $model_init_hash = { map { $_ => $self->ppo()->$_() } keys %{$self->ppo()->attributes()} };
	delete $model_init_hash->{_id};			 
	$model_init_hash->{id} = $args->{newid};	
	$model_init_hash->{owner} = $args->{owner};
	$model_init_hash->{biomassReaction} = $biomassCopy->id();
	# Configuration needed for new() itself
	$model_init_hash->{runPreliminaryReconstrution} = 0;
	$model_init_hash->{gapfilling} = 0;
	
	my $mdl = ModelSEED::FIGMODEL::FIGMODELmodel->new($self->figmodel(), $args->{newid}, $model_init_hash);
	# Give the current user temporary admin rights 
#	$self->changeRight($self->figmodel()->user(), "admin", "force");
	ModelSEED::FIGMODEL::FIGMODELERROR("Error constructing new model ".$args->{newid}) if(!defined($mdl));
	# Copy model rxnmdl ppo data
	my $old_rxnmdls = $self->db()->get_objects("rxnmdl", { MODEL => $self->id() });
	foreach my $old_rxnmdl (@$old_rxnmdls) {
		my $hash = { map { $_ => $old_rxnmdl->$_() } keys %{$old_rxnmdl->attributes()} };
		delete $hash->{_id};
		$hash->{MODEL} = $args->{newid};
		$mdl->db()->create_object("rxnmdl", $hash); 
	}
	# Copy over modelversions
	my $model_versions = $self->db()->get_objects("model_version", { canonicalID => $self->id() });
	foreach my $mdl_version (@$model_versions) {
		my $hash = { map { $_ => $mdl_version->$_() } keys %{$mdl_version->attributes()} };
		delete $hash->{_id};
		# id needs to be "base.v\d+" keep the ".v\d+" use newbase
		my $version;
		if($hash->{id} =~ /(v\d+)$/) {
		   $version = $1; 
		}
		$hash->{id} = $args->{newid} . ".v$version";
		$hash->{canonicalID} = $args->{newid};
		$mdl->db()->create_object("model_version", $hash);
	}
	# Run process model
	$mdl->processModel();
	# Remove temporary admin rights if not the owner
#	if($self->owner() ne $self->figmodel()->user()) {
#		$self->changeRight($self->figmodel()->user(), "none");
#	} 
	return $mdl;
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELmodel->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 db
Definition:
	FIGMODEL = FIGMODELmodel->db();
Description:
	Returns FIGMODELdatabase object;
=cut
sub db {
	my ($self) = @_;
	return $self->figmodel()->database();
}

=head3 genomeObj
Definition:
	FIGMODELgenome = FIGMODELmodel->genomeObj();
Description:
	Returns the genome object for the model
=cut
sub genomeObj {
	my ($self) = @_;
	if (lc($self->genome()) eq "none" && lc($self->genome()) eq "unknown") {
		return undef;
	}
	if (!defined($self->{_genomeObj})) {
		$self->{_genomeObj} = $self->figmodel()->get_genome($self->genome());
	}
	return $self->{_genomeObj};
}

=head3 userObj
Definition:
	PPOuser = FIGMODELmodel->userObj();
Description:
	Returns the user object for the model owner
=cut
sub userObj {
	my ($self) = @_;
	if (!defined($self->{_userobj}) && defined($self->ppo()) && $self->ppo()->owner() ne "master") {
		$self->{_userobj} = $self->db()->get_object("user",{login => $self->ppo()->owner()});
	}
	return $self->{_userobj};
}

=head3 ppo
Definition:
	FIGMODEL = FIGMODELmodel->ppo();
Description:
	Returns the ppo object for the model
=cut
sub ppo {
	my ($self,$object) = @_;
	if (defined($object)) {
		$self->{_data} = $object;
	}
	return $self->{_data};
}

=head3 id
Definition:
	string = FIGMODELmodel->id();
Description:
	Returns model id
=cut
sub id {
	my ($self) = @_;
	if(not defined($self->ppo()) && defined($self->{_id})) {
		my $parse = $self->parseId($self->{_fullId});
		return $self->{_id} = $parse->{canonical}; 
	}
	   if (defined($self->ppo()->attributes()->{canonicalID})) {
		   return $self->ppo()->canonicalID();
	   }	
	return $self->ppo()->id();
}

=head33 fullId
Definition:
	string = FIGMODELmodel->fullId()
DescriptioN
	Returns the complete id, including base, version number, user
=cut
sub fullId {
	my ($self, $id) = @_;
	if(defined($id)) {
		$self->{_fullId} = $id;
	}
	return $self->{_fullId};
}

=head3 status
Definition:
	int::model status = FIGMODELmodel->status();
Description:
	Returns the current status of the SEED model associated with the input genome ID.
	model status = 1: model exists
	model status = 0: model is being built
	model status = -1: model does not exist
	model status = -2: model build failed
=cut
sub status {
	my ($self) = @_;
	return $self->ppo()->status();
}

=head3 message
Definition:
	string::model message = FIGMODELmodel->message();
Description:
	Returns a message associated with the models current status
=cut
sub message {
	my ($self) = @_;
	return $self->ppo()->message();
}

=head3 set_status
Definition:
	(success/fail) = FIGMODELmodel->set_status(int::new status,string::status message);
Description:
	Changes the current status of the SEED model
	new status = 1: model exists
	new status = 0: model is being built
	new status = -1: model does not exist
	new status = -2: model build failed
=cut
sub set_status {
	my ($self,$NewStatus,$Message) = @_;
	$self->ppo()->status($NewStatus);
	$self->ppo()->message($Message);
	return $self->config("SUCCESS")->[0];
}

=head3 genome
Definition:
	string = FIGMODELmodel->genome();
Description:
	Returns model genome
=cut
sub genome {
	my ($self) = @_;
	return $self->ppo()->genome();
}

=head3 source
Definition:
	string = FIGMODELmodel->source();
Description:
	Returns model source
=cut
sub source {
	my ($self) = @_;
	return $self->ppo()->source();
}

=head3 get_model_type
Definition:
	string = FIGMODELmodel->get_model_type();
Description:
	Returns the type of the model
=cut
sub get_model_type {
	my ($self) = @_;
	if ($self->ppo()->source() =~ m/MGRAST/) {
		return "metagenome";
	}
	return "genome";
}

=head3 owner
Definition:
	string = FIGMODELmodel->owner();
Description:
	Returns the username for the model owner
=cut
sub owner {
	my ($self) = @_;
	return $self->ppo()->owner();
}

=head3 users
Definition:
	{string:user login => string:right} = FIGMODELmodel->users();
Description:
=cut
sub users {
	my ($self) = @_;
	my $rows = $self->db()->get_objects("permissions",
		{ id => $self->id(), type => "model"});
	my $obj = { map { $_->user() => $_->permission() } @$rows };
	# Now add all of the model admin's with "admin" privilage, unless they're already defined
	foreach my $admin (keys %{$self->figmodel()->config("model administrators")}) {
		unless(defined($obj->{$admin})) {
			$obj->{$admin} = "admin";
		}
	}
	# Add a "view" right to PUBLIC for public models
	if(!defined($self->ppo())) {
		Carp::cluck "no ppo here!";
	}
	if($self->ppo()->public() eq 1) {
		$obj->{PUBLIC} = "view";
	}
	return $obj;
}

=head3 changeRight
Definition:
	string:error message = FIGMODELmodel->changeRight(string:username,string right);
=cut
sub changeRight {
	my ($self, $user, $permission, $force) = @_;
	return unless($self->isAdministrable() || $force eq "force");
	my $model_hash = {
		id => $self->id(),
		type => "model",
		user => $user 
	};
	my $biomass_hash = {
		id => $self->biomassReaction(),
		type => "bof",
		user => $user
	};
	if($permission eq "" || $permission eq "none") {
		my $mdl = $self->db()->get_object("permissions", $model_hash);
		my $bio = $self->db()->get_object("permissions", $biomass_hash);
		$mdl->delete() if defined($mdl);
		$bio->delete() if defined($bio);
		return;
	}
	# give the user the permission on the model object
	my $existing_mdl = $self->db()->get_object("permissions", $model_hash);
	if(defined($existing_mdl)) {
		$existing_mdl->permission($permission);
	} else {
		$model_hash->{permission} = $permission;
		$self->db()->create_object("permissions", $model_hash);
	}
	# give the user the permission on the biomass reaction
	my $existing_bio = $self->db()->get_object("permissions", $biomass_hash);
	if(defined($existing_bio)) {
	   	$existing_bio->permission($permission);
	} else {
		$biomass_hash->{permission} = $permission;
		$self->db()->create_object("permissions", $biomass_hash);
	}
}

=head3 rights
Definition:
	string = FIGMODELmodel->rights(string::username);
Description:
	Returns one of "view", "admin", "none" for the user.
	If no user is supplied, returns the rights for the current user.
=cut
sub rights {
	my ($self,$username) = @_;
	if (!defined($username)) {
		$username = $self->figmodel()->user();
	}
	my $rights = $self->users();
	if(defined($rights->{$username})) {
		return $rights->{$username};
	} elsif(defined($rights->{PUBLIC})) {
		return $rights->{PUBLIC};
	} else {
		return "none";
	}
}

=head3 create_model_rights
Definition:
	string:error = FIGMODELmodel->create_model_rights();
Description:
	Creates rights associated with model. Should be called when models are first created.
=cut
sub create_model_rights {
	my ($self) = @_;
	# Set the model to private ownership unless it is owned by master
	if($self->owner() eq "master") {
		$self->ppo()->public(1);
	} else {
		$self->ppo()->public(0);
		# Give the model owner admin rights over the model, biomass
		$self->changeRight($self->owner(), "admin","force");
	}
}
=head3 transfer_genome_rights_to_model
Definition:
	string:error = FIGMODELmodel->transfer_genome_rights_to_model();
Description:
	Transfers the rights associated with the modeled genome to the model itself
=cut
sub transfer_genome_rights_to_model {
	my ($self) = @_;
	my $svr = $self->figmodel()->server("MSSeedSupportClient");
	my $output = $svr->users_for_genome({
		genome => $self->genome(),
		username => $self->figmodel()->userObj()->login(),
		password => $self->figmodel()->userObj()->password()
	});
	ModelSEED::FIGMODEL::FIGMODELERROR("Could not load user list for model!") if (!defined($output->{$self->genome()}));
	foreach my $user (keys(%{$output->{$self->genome()}})) {
		$self->db()->change_permissions({
			objectID => $self->id(),
			permission => $output->{$self->genome()}->{$user},
			user => $user,
			type => "model"
		});
		$self->db()->change_permissions({
			objectID => $self->biomassReaction(),
			permission => $output->{$self->genome()}->{$user},
			user => $user,
			type => "bof"
		});
	}
}
=head3 transfer_rights_to_biomass
Definition:
	string = FIGMODELmodel->transfer_rights_to_biomass();
Description:
	Transfers the rights for the model to the biomass reaction
=cut
sub transfer_rights_to_biomass {
	my ($self,$biomass) = @_;
	my $bofObj = $self->biomassObject();
	$bofObj->public($self->ppo()->public());
	$bofObj->owner($self->ppo()->owner());
	my $mdlRights = $self->db()->get_objects("permissions", { id => $self->id(), type => "model" });
	my $bofRightsByUser = { map { $_->user() => $_ } @{$self->db()->get_objects("permissions",
								{ id => $bofObj->id(), type => "bof" })} };
	foreach my $mdlRight (@$mdlRights) {
		my $user = $mdlRight->user();
		if(defined($bofRightsByUser->{$user})) {
			$bofRightsByUser->{$user}->permission($mdlRight->permission());
		} else {
			my $hash = { id => $bofObj->id(), type => "bof", permission => $mdlRight->permission(), user => $mdlRight->user() };
			$self->db()->create_object("permission", $hash);
		}
	}
	return {msg => undef,error => undef,success => 1};
}

=head3 name
Definition:
	string = FIGMODELmodel->name();
Description:
	Returns the name of the organism or metagenome sample being modeled
=cut
sub name {
	my ($self) = @_;
	$self->ppo()->name();
}

=head3 get_reaction_class
Definition:
	string = FIGMODELmodel->get_reaction_class(string::reaction ID);
Description:
	Returns reaction class
=cut
sub get_reaction_class {
	my ($self,$reaction,$nohtml,$brief_flux) = @_;

	if (!-e $self->directory()."ReactionClassification-".$self->id().".tbl") {
		if (!defined($self->{_reaction_classes})) {
			$self->{_reaction_classes} = $self->figmodel()->database()->load_table($self->directory()."ReactionClassification-".$self->id()."-Complete.tbl",";","|",0,["REACTION"]);
			if (!defined($self->{_reaction_classes})) {
				return undef;
			}
		}

		my $ClassRow = $self->{_reaction_classes}->get_row_by_key($reaction,"REACTION");
		if (defined($ClassRow) && defined($ClassRow->{CLASS})) {
			my $class;
			my $min = $ClassRow->{MIN}->[0];
			my $max = $ClassRow->{MAX}->[0];
			if ($ClassRow->{CLASS}->[0] eq "Positive") {
				$class = "Essential =>";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $class.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Negative") {
				$class = "Essential <=";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $class.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Positive variable") {
				$class = "Active =>";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $class.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Negative variable") {
				$class = "Active <=";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $class.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Variable") {
				$class = "Active <=>";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $class.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Blocked") {
				$class = "Inactive";
			} elsif ($ClassRow->{CLASS}->[0] eq "Dead") {
				$class = "Disconnected";
			}

			if (!defined($nohtml) || $nohtml ne "1") {
				$class = "<span title=\"Flux:".$min." to ".$max."\">".$class."</span>";
			}

			return $class;
		}
		return undef;
	}

	if (!defined($self->{_reaction_classes})) {
		$self->{_reaction_classes} = $self->figmodel()->database()->load_table($self->directory()."ReactionClassification-".$self->id().".tbl",";","|",0,["REACTION"]);
		if (!defined($self->{_reaction_classes})) {
			return undef;
		}
	}

	my $ClassRow = $self->{_reaction_classes}->get_row_by_key($reaction,"REACTION");
	my $classstring = "";
	if (defined($ClassRow) && defined($ClassRow->{CLASS})) {
		for (my $i=0; $i < @{$ClassRow->{CLASS}};$i++) {
			if (length($classstring) > 0) {
				$classstring .= "<br>";
			}
			my $NewClass;
			my $min = $ClassRow->{MIN}->[$i];
			my $max = $ClassRow->{MAX}->[$i];
			if ($ClassRow->{CLASS}->[$i] eq "Positive") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Essential =>";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $NewClass.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Negative") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Essential <=";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $NewClass.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Positive variable") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Active =>";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $NewClass.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Negative variable") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Active <=";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $NewClass.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Variable") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Active <=>";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $NewClass.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Blocked") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Inactive";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Dead") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Disconnected";
			}

			if (!defined($nohtml) || $nohtml ne "1") {
				$NewClass = "<span title=\"Flux:".$min." to ".$max."\">".$NewClass."</span>";
			}
			$classstring .= $NewClass;
		}
	}
	return $classstring;
}

=head3 get_biomass
Definition:
	string = FIGMODELmodel->get_biomass();
Description:
	Returns data for the biomass reaction
=cut
sub get_biomass {
	my ($self) = @_;
	return $self->get_reaction_data($self->ppo()->biomassReaction());
}

=head3 get_reaction_data
Definition:
	string = FIGMODELmodel->get_reaction_data(string::reaction ID <or> {-id=>string:reaction ID,-index=>integer:reaction index});
Description:
	Returns model reaction data
=cut
sub get_reaction_data {
	my ($self,$args) = @_;
	if (ref($args) ne "HASH") {
		if ($args =~ m/^\d+$/) {
			$args = {-index => $args};
		} elsif ($args =~ m/[rb][ix][no]\d\d\d\d\d/) {
			$args = {-id => $args};
		} else {
			return $self->error_message({function => "get_reaction_data",args => $args,message=>"No ID or index specified!"});
		}
	}
	if (!defined($args->{-id}) && !defined($args->{-index})) {
		return $self->error_message({function => "get_reaction_data",args => $args,message=>"No ID or index specified!"});
	}
	my $rxnTbl = $self->reaction_table();
	if (!defined($rxnTbl)) {
		return undef;
	}
	my $rxnData;
	if (defined($args->{-id})) {
		$rxnData = $rxnTbl->get_row_by_key($args->{-id},"LOAD");
	} elsif (defined($args->{-index})) {
		$rxnData = $rxnTbl->get_row($args->{-index});
	}
	return $rxnData;
}

=head3 getRoleTable
Definition:
	FIGMODELTable = FIGMODELmodel->getRoleTable();
Description:
	Returns a FIGMODELTable with data on functional roles
=cut
sub role_table {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{create=>0});
	if (defined($args->{error})) {return $self->error_message({function => "role_table",args => $args});}
	if (!defined($self->getCache("roletable"))) {
		my $tbl;
		if ($args->{create} == 1 || !-e $self->directory()."Roles.tbl") {
			my $pegTbl = $self->feature_table();
			$tbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["ROLE","REACTIONS","GENES","ESSENTIAL"],$self->directory()."Roles.tbl",["ROLE","REACTIONS","GENES","ESSENTIAL"],";","|");
			my $gene;
			for(my $i=0; $i < $pegTbl->size(); $i++) {
				my $row = $pegTbl->get_row($i);
				if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
					$gene = $1;
					if (defined($row->{ROLES}->[0])) {
						for(my $j=0; $j < @{$row->{ROLES}}; $j++) {
							my $newrow = $tbl->get_row_by_key($row->{ROLES}->[$j],"ROLE",1);
							push(@{$newrow->{GENES}},$gene);
							if (defined($row->{$self->id()."PREDICTIONS"})) {
								my $essential = 0;
								for (my $k=0; $k < @{$row->{$self->id()."PREDICTIONS"}}; $k++) {
									if ($row->{$self->id()."PREDICTIONS"}->[$k] eq "Complete:essential") {
										$essential = 1;
									}
								}
								$newrow->{ESSENTIAL}->[0] = $essential;
							}
							if (defined($row->{$self->id()."REACTIONS"})) {
								for (my $k=0; $k < @{$row->{$self->id()."REACTIONS"}}; $k++) {
									$tbl->add_data($newrow,"REACTIONS",$row->{$self->id()."REACTIONS"}->[$k],1);
								}
							}
						}
					}
				}
			}
			my $gfroles = $self->gapfilled_roles();
			foreach my $gfrole (keys(%{$gfroles})) {
				my $newrow = $tbl->get_row_by_key($gfrole,"ROLE",1);
				$newrow->{REACTIONS} = $gfroles->{$gfrole};
				$newrow->{ESSENTIAL}->[0] = 1;
			}
			$tbl->save();
		} else {
			$tbl = $self->figmodel()->database()->load_table($self->directory()."Roles.tbl",";","|",0,["ROLE","REACTIONS","GENES","ESSENTIAL"]);		
		}
		$self->setCache("roletable",$tbl);
	}
	return $self->getCache("roletable");
}
=head3 reaction_notes
Definition:
	string = FIGMODELmodel->reaction_notes(string::reaction ID);
Description:
	Returns reaction notes
=cut
sub reaction_notes {
	my ($self,$rxn) = @_;
	my $rxnTbl = $self->reaction_table();
	if (!defined($rxnTbl)) {
		return "None";
	}
	my $rxnData = $rxnTbl->get_row_by_key($rxn,"LOAD");;
	if (!defined($rxnData)) {
		return "Not in model";	
	}
	if (defined($rxnData->{NOTES})) {
		return join("<br>",@{$rxnData->{NOTES}});
	} 
	return "None"
}

=head3 display_reaction_flux
Definition:
	string = FIGMODELmodel->get_reaction_flux({id => string:reaction id,fluxobj => PPOfbaresult:PPO object with flux data});
Description:
	Returns the flux associated with the specified reaction in the fba results databases
=cut
sub get_reaction_flux {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["id","fluxobj"]);
	if (defined($args->{error})) {return $self->error_message({function => "get_reaction_flux",args => $args});}
	if (!defined($self->{_fluxes}->{$args->{fluxobj}->_id()})) {
		if ($args->{fluxobj}->flux() eq "none") {
			return "None";	
		}
		my $tbl = $self->reaction_table();
		if (!defined($tbl)) {
			return undef;	
		}
		for(my $i=0; $i < $tbl->size(); $i++) {
			$self->{_fluxes}->{$args->{fluxobj}->_id()}->{$tbl->get_row($i)->{LOAD}->[0]} = 0;
		}
		my @temp = split(/;/,$args->{fluxobj}->flux());
		for (my $i =0; $i < @temp; $i++) {
			my @temptemp = split(/:/,$temp[$i]);
			if (@temptemp >= 2) {
				$self->{_fluxes}->{$args->{fluxobj}->_id()}->{$temptemp[0]} = $temptemp[1];
			}
		}
	}
	if (!defined($self->{_fluxes}->{$args->{fluxobj}->_id()}->{$args->{id}})) {
		return "Not in model";	
	}
	return $self->{_fluxes}->{$args->{fluxobj}->_id()}->{$args->{id}};
}

=head3 get_reaction_equation
Definition:
	string = FIGMODELmodel->get_reaction_equation({-id=>string:reaction ID,-index=>integer:reaction index,-style=>NAME/ID/ABBREV});
Description:
	Returns the reaction equation formatted with the model directionality and compartment
=cut
sub get_reaction_equation {
	my ($self,$args) = @_;
	my $rxnData = $self->get_reaction_data($args);
	if (!defined($rxnData)) {
		return undef;
	}
	my $obj;
	if ($rxnData->{LOAD}->[0] =~ m/(rxn\d\d\d\d\d)/) {
		my $rxnID = $1;
		my $rxnHash = $self->figmodel()->database()->get_object_hash({type=>"reaction",attribute=>"id",-onlyIfCached=>1});
		if (defined($rxnHash)) {
			if (defined($rxnHash->{$rxnID})) {
				$obj = $rxnHash->{$rxnID}->[0];
			}
		} else {
			$obj = $self->figmodel()->database()->get_object("reaction",{id => $rxnID});
		}
	} elsif ($rxnData->{LOAD}->[0] =~ m/(bio\d\d\d\d\d)/) {
		$obj = $self->figmodel()->database()->get_object("bof",{id => $1});
	}
	if (!defined($obj)) {
		return $self->error_message({function => "get_reaction_equation",args => $args,message => "can't find reaction ".$rxnData->{LOAD}->[0]." in database!"});
	}
	my $cpdHash = $self->figmodel()->database()->get_object_hash({type=>"compound",attribute=>"id",useCache=>1});
	my $equation = $obj->equation();
	my $direction = $rxnData->{DIRECTIONALITY}->[0];
	#Setting reaction directionality
	$equation =~ s/<*=>*/$direction/;
	#Adjusting reactants based on input
	if ((defined($args->{-style}) && $args->{-style} ne "ID") || $rxnData->{COMPARTMENT}->[0] ne "c") {
		$_ = $equation;
		my @reactants = /(cpd\d\d\d\d\d)/g;
		for (my $i=0; $i < @reactants; $i++) {
			my $origCpd = $reactants[$i];
			my $cpd = $origCpd;
			if (defined($args->{-style}) && $args->{-style} eq "NAME") {
				if (defined($cpdHash->{$origCpd}) && defined($cpdHash->{$origCpd}->[0]->name()) && length($cpdHash->{$origCpd}->[0]->name()) > 0) {
					$cpd = $cpdHash->{$origCpd}->[0]->name();
				}
			} elsif (defined($args->{-style}) && $args->{-style} eq "ABBREV") {
				if (defined($cpdHash->{$origCpd}) && defined($cpdHash->{$origCpd}->[0]->abbrev()) && length($cpdHash->{$origCpd}->[0]->abbrev()) > 0) {
					$cpd = $cpdHash->{$origCpd}->[0]->abbrev();
				}
			}
			if ($rxnData->{COMPARTMENT}->[0] ne "c") {
				$cpd .= "[".$rxnData->{COMPARTMENT}->[0]."]";
			}
			if ($cpd eq "all") {
				$cpd = $origCpd;
			}
			$equation =~ s/$origCpd/$cpd/g;	
		}
		$equation =~ s/\[c\]\[/[/g;
	}
	if ($equation !~ m/=/) {
		$equation = $rxnData->{DIRECTIONALITY}->[0]." ".$equation;	
	}
	return $equation;
}

=head3 load_model_table
Definition: 
	FIGMODELTable = FIGMODELmodel->load_model_table(string:table name,0/1:refresh the table));
Description: 
	Returns the table specified by the input filename. Table will be stored in a file in the model directory.
=cut
sub load_model_table {
	my ($self,$name,$refresh) = @_;
	if (defined($refresh) && $refresh == 1) {
		delete $self->{"_".$name};
	}
	if (!defined($self->{"_".$name})) {
		my $tbldef = $self->figmodel()->config($name);
		if (!defined($tbldef)) {
			return undef;
		}
		my $itemDelim = "|";
		if (defined($tbldef->{itemdelimiter}->[0])) {
			$itemDelim = $tbldef->{itemdelimiter}->[0];
			if ($itemDelim eq "SC") {
				$itemDelim = ";";	
			}
		}
		my $columnDelim = "\t";
		if (defined($tbldef->{columndelimiter}->[0])) {
			$columnDelim = $tbldef->{columndelimiter}->[0];
			if ($columnDelim eq "SC") {
				$columnDelim = ";";	
			}
		}
		my $suffix = ".tbl";
		if (defined($tbldef->{filename_suffix}->[0])) {
			$suffix = $tbldef->{filename_suffix}->[0];
		}
		my $filename = $self->directory().$name."-".$self->id().$self->selected_version().$suffix;
		if (defined($tbldef->{filename_prefix}->[0])) {
			if ($tbldef->{filename_prefix}->[0] eq "NONE") {
				$filename = $self->directory().$self->id().$self->selected_version().$suffix;
			} else {
				$filename = $self->directory().$tbldef->{filename_prefix}->[0]."-".$self->id().$self->selected_version().$suffix;
			}
		}
		if (-e $filename) {
			$self->{"_".$name} = $self->figmodel()->database()->load_table($filename,$columnDelim,$itemDelim,$tbldef->{headingline}->[0],$tbldef->{hashcolumns});
		} else {
			if (defined($tbldef->{prefix})) {
				$self->{"_".$name} = ModelSEED::FIGMODEL::FIGMODELTable->new($tbldef->{columns},$filename,$tbldef->{hashcolumns},$columnDelim,$itemDelim,join(@{$tbldef->{prefix}},"\n"));
			} else {
				$self->{"_".$name} = ModelSEED::FIGMODEL::FIGMODELTable->new($tbldef->{columns},$filename,$tbldef->{hashcolumns},$columnDelim,$itemDelim);
			}
		}
	}
	return $self->{"_".$name};
}

=head3 create_table_prototype
Definition:
	FIGMODELTable::table = FIGMODELmodel->create_table_prototype(string::table);
Description:
	Returns a empty FIGMODELTable with all the metadata associated with the input table name
=cut
sub create_table_prototype {
	my ($self,$TableName) = @_;
	#Checking if the table definition exists in the FIGMODELconfig file
	my $tbldef = $self->figmodel()->config($TableName);
	if (!defined($tbldef)) {
		return $self->error_message({function => "create_table_prototype",message => "Definition not found for ".$TableName});
	}
	#Checking that this is a database table
	if (!defined($tbldef->{tabletype}) || $tbldef->{tabletype}->[0] ne "ModelTable") {
		return $self->error_message({function => "create_table_prototype",message => $TableName." is not a model table!"});
	}
	#Setting default values for table parameters
	my $prefix;
	if (defined($tbldef->{prefix})) {
		$prefix = join("\n",@{$self->config($TableName)->{prefix}})."\n";
	}
	my $itemDelim = "|";
	if (defined($tbldef->{itemdelimiter}->[0])) {
		$itemDelim = $tbldef->{itemdelimiter}->[0];
		if ($itemDelim eq "SC") {
			$itemDelim = ";";	
		}
	}
	my $columnDelim = "\t";
	if (defined($tbldef->{columndelimiter}->[0])) {
		$columnDelim = $tbldef->{columndelimiter}->[0];
		if ($columnDelim eq "SC") {
			$columnDelim = ";";	
		}
	}
	my $suffix = ".tbl";
	if (defined($tbldef->{filename_suffix}->[0])) {
		$suffix = $tbldef->{filename_suffix}->[0];
	}
	my $filename = $self->directory().$TableName."-".$self->id().$self->selected_version().$suffix;
	if (defined($tbldef->{filename_prefix}->[0])) {
		if ($tbldef->{filename_prefix}->[0] eq "NONE") {
			$filename = $self->directory().$self->id().$self->selected_version().$suffix;
		} else {
			$filename = $self->directory().$tbldef->{filename_prefix}->[0]."-".$self->id().$self->selected_version().$suffix;
		}
	}
	#Creating the table prototype
	my $tbl = ModelSEED::FIGMODEL::FIGMODELTable->new($tbldef->{columns},$filename,$tbldef->{hashcolumns},$columnDelim,$itemDelim,$prefix);
	return $tbl;
}

=head3 get_reaction_number
Definition:
	int = FIGMODELmodel->get_reaction_number();
Description:
	Returns the number of reactions in the model
=cut
sub get_reaction_number {
	my ($self) = @_;
	if (!defined($self->reaction_table())) {
		return 0;
	}
	return $self->reaction_table()->size();
}


=head3 essentials_table
Definition:
	FIGMODELTable = FIGMODELmodel->essentials_table();
Description:
	Returns FIGMODELTable with the essential genes for the model
=cut
sub essentials_table {
	my ($self,$clear) = @_;
    my $rows = $self->db()->get_objects("mdless", { MODEL => $self->id() }); 
    my $tbl = $self->db()->ppo_rows_to_table({
        headings => ["MEDIA", "MODEL", "ESSENTIAL GENES", "PARAMETERS"],
        item_delimiter => ";",
        delimiter => "\t",
        hash_headings => ["MODEL", "MEDIA"],
        heading_remap => {
            MEDIA => "MEDIA",
            essentials => "ESSENTIAL GENES",
            MODEL => "MODEL",
            parameters => "PARAMETERS",
            }, 
        }, $rows);
	return $tbl;
}

=head3 model_history
Definition:
	FIGMODELTable = FIGMODELmodel->model_history();
Description:
	Returns FIGMODELTable with the history of model changes
=cut
sub model_history {
	my ($self,$clear) = @_;
	return $self->load_model_table("ModelHistory",$clear);
}
=head3 featureHash
Definition:
	{string:feature ID => string:data} = FIGMODELmodel->featureHash();
Description:
	Returns a hash of model related data for each gene represented in the model.
=cut
sub featureHash {
	my ($self) = @_;
	if (!defined($self->{_featurehash})) {
		my $rxnTable = $self->reaction_table();
		if (!defined($rxnTable)) {
			return $self->error_message({function => "featureHash",message => "Could not get reaction table!"});
		}
		for (my $i=0; $i < $rxnTable->size(); $i++) {
			my $Row = $rxnTable->get_row($i);
			if (defined($Row) && defined($Row->{"ASSOCIATED PEG"})) {
				foreach my $GeneSet (@{$Row->{"ASSOCIATED PEG"}}) {
					my $temp = $GeneSet;
					$temp =~ s/\+/|/g;
					  $temp =~ s/\sAND\s/|/gi;
					  $temp =~ s/\sOR\s/|/gi;
					  $temp =~ s/[\(\)\s]//g;
					  my @GeneList = split(/\|/,$temp);
					  foreach my $Gene (@GeneList) {
						  $self->{_featurehash}->{$Gene}->{reactions}->{$Row->{"LOAD"}->[0]} = 1;
					  }
				}
			  }
		}
		#Loading predictions
		my $esstbl = $self->essentials_table();
		my @genes = keys(%{$self->{_featurehash}});
		for (my $i=0; $i < $esstbl->size(); $i++) {
			my $row = $esstbl->get_row($i);
			if (defined($row->{MEDIA}->[0]) && defined($row->{"ESSENTIAL GENES"}->[0])) {
				for (my $j=0; $j < @genes; $j++) {
					$self->{_featurehash}->{$genes[$j]}->{essentiality}->{$row->{MEDIA}->[0]} = 0;
				}
				for (my $j=0; $j < @{$row->{"ESSENTIAL GENES"}}; $j++) {
					$self->{_featurehash}->{$row->{"ESSENTIAL GENES"}->[$j]}->{essentiality}->{$row->{MEDIA}->[0]} = 1;
				}
			}
		}
	}
	return $self->{_featurehash};
}

=head3 reaction_class_table
Definition:
	FIGMODELTable = FIGMODELmodel->reaction_class_table();
Description:
	Returns FIGMODELTable with the reaction class data, and creates the table file  if it does not exist
=cut
sub reaction_class_table {
	my ($self,$clear) = @_;
	return $self->load_model_table("ModelReactionClasses",$clear);
}

=head3 compound_class_table
Definition:
	FIGMODELTable = FIGMODELmodel->compound_class_table();
Description:
	Returns FIGMODELTable with the compound class data, and creates the table file  if it does not exist
=cut
sub compound_class_table {
	my ($self,$clear) = @_;
	return $self->load_model_table("ModelCompoundClasses",$clear);
}

=head3 get_essential_genes
Definition:
	[string::peg ID] = FIGMODELmodel->get_essential_genes(string::media condition);
Description:
	Returns an reference to an array of the predicted essential genes during growth in the input media condition
=cut
sub get_essential_genes {
	my ($self,$media) = @_;
	my $tbl = $self->essentials_table();
	my $row = $tbl->get_row_by_key($media,"MEDIA");
	if (defined($row)) {
		return $row->{"ESSENTIAL GENES"};	
	}
	return undef;
}
=head3 get_compound_data
Definition:
	{string:key=>[string]:values} = FIGMODELmodel->get_compound_data(string::compound ID);
Description:
	Returns model compound data
=cut
sub get_compound_data {
	my ($self,$compound) = @_;
	if (!defined($self->compound_table())) {
		return undef;
	}
	if ($compound =~ m/^\d+$/) {
		return $self->compound_table()->get_row($compound);
	}
	return $self->compound_table()->get_row_by_key($compound,"DATABASE");
}

=head3 get_feature_data
Definition:
	{string:key=>[string]:values} = FIGMODELmodel->get_feature_data(string::feature ID);
Description:
	Returns model feature data
=cut
sub get_feature_data {
	my ($self,$feature) = @_;
	if (!defined($self->feature_table())) {
		return undef;
	}
	if ($feature =~ m/^\d+$/) {
		return $self->feature_table()->get_row($feature);
	}
	if ($feature =~ m/(peg\.\d+)/) {
		$feature = $1;
	}
	return $self->feature_table()->get_row_by_key("fig|".$self->genome().".".$feature,"ID");
}



=head3 public
Definition:
	1/0 = FIGMODELmodel->public();
Description:
	Returns 1 if the model is public, and zero otherwise
=cut
sub public {
	my ($self) = @_;
	return $self->ppo()->public();
}

=head3 directory
Definition:
	string = FIGMODELmodel->directory();
Description:
	Returns model directory
=cut
sub directory {
	my ($self, $newDir) = @_;
	if(defined($newDir)) {
		$self->{_directory} = $newDir;
	} 
	my $owner;
	# disabling caching, as this seems to lead to stale-state at times
	#unless(defined($self->{_directory})) {
		my $parts = $self->parseId($self->fullId());
		if(defined($parts->{owner}) && $parts->{owner} ne 'master') {
			my $user_obj = $self->figmodel()->database()->get_object("user", {_id => $parts->{owner}});
			$owner = $user_obj->login() if(defined($user_obj));
		} else {
			$owner = "master";
		}
		my $path = (defined($owner)) ? $owner."/" : "";
		$path .= $parts->{canonical}."/".$parts->{version}."/";
		my $model_dirs = $self->figmodel()->config('model directory');
		foreach my $model_dir (@$model_dirs) {
            $model_dir =~ s/\/$//;
			if(-d "$model_dir/$path") {
				$self->{_directory} = "$model_dir/$path";
				last;
			}
		}
		if(!defined($self->{_directory}) && defined($self->ppo())) {
			$self->{_directory} = "$model_dirs->[0]/$path";
		}
	#}
	return $self->{_directory};
}


=head3 parseId 
Definition:
	{} = FIGMODELmodel->parseId($id);
Description:
	Returns:
canonical => canonical id in model table
full => cannonical + .v{version}
owner => user id, not username
version => version number
=cut
sub parseId {
	my ($self, $id) = @_;
	my ($owner, $model_version, $canonical) = undef;
	if($id =~ /^(.+)\.v(\d+)$/) {
		 $model_version = $2;
		 $id = $1;
	}
	$canonical = $id;
	if($id =~ /^Seed\d+\.\d+/ || $id =~ /^Opt\d+\.\d+/) {
		if($id =~ /\d+\.\d+\.(\d+)$/) {
			$owner = $1;
		}
	} elsif ($id =~ /\.(\d+)$/) {
		$owner = $1;
	}
	if (defined($self->ppo())) {
		$model_version = $self->ppo()->version();
	}
	return { canonical => $canonical, owner => $owner, version => $model_version,
			 full => "$canonical.v$model_version" };
}

=head3 filename
Definition:
	string = FIGMODELmodel->filename();
Description:
	Returns model filename
=cut
sub filename {
	my ($self) = @_;

	return $self->directory().$self->id().$self->selected_version().".txt";
}

=head3 version
Definition:
	string = FIGMODELmodel->version();
Description:
	Returns the version of the model
=cut
sub version {
	my ($self) = @_;
	if (!defined($self->{_version}) && !defined($self->ppo())) {
		return $self->{_version} = $self->parseId($self->id())->{version};
	} elsif(defined($self->ppo())) {
		return $self->ppo()->version();
	} else {
		return $self->{_version};
	}
}

sub ppo_version  {
	my ($self) = @_;
	my $mdl = $self->figmodel()->database()->get_object('model', { id => $self->id() });
	return (defined($mdl)) ? $mdl->version() : undef;
}

=head3 clearPermissions
Definition:
	FIGMODELmodel->clearPermissions()
Description:
	This function removes all existing permissions on a model and it's
	associated biomass reaction.
=cut
sub clearPermissions {
	my ($self) = @_;
	# Don't modify the model public() feild
	# Remove all model admin / view / edit privileges
	{
		my $perms = $self->db()->get_objects("permissions",
			{ id => $self->id(), type => "model"});
		map { $_->delete() } @$perms;
	}
	# Remove all permissions on biomass object
	{
		my $perms = $self->db()->get_objects("permissions",
			{ id => $self->biomassReaction(), type => "bof"});
		map { $_->delete() } @$perms;
	}
}

=head3 isEditable
Definition:
	boolean = FIGMODELmodel->isEditable();
Description:
	Returns true if the model is editable:
	1) owned by the current user or admin
	2) not versioned 
=cut
sub isEditable {
	my ($self) = @_;
	# check that this model is editable
	return 0 unless($self->version() == $self->ppo_version());
	# check that this user can edit the model
	my $user = $self->figmodel()->user();
	my $users = $self->users();
	return 0 unless(defined($users->{$user}) && (
		$users->{$user} eq 'admin' || $users->{$user} eq 'edit'));
	return 1;
} 


=head3 isAdministrable
Defintion:
	boolean = FIGMODELmodel->isAdministrable()
Description:
	Returns true if the model can be administered by the current user.
	Note that isAdministrable DOES NOT IMPLY isEditable!
=cut 
sub isAdministrable { 
	my ($self) = @_;
	# check that this user can edit the model
	my $user = $self->figmodel()->user();
	my $users = $self->users();
	return 0 unless(defined($users->{$user}) && $users->{$user} eq "admin");
	return 1;
}
	

=head3 selected_version
Definition:
	string = FIGMODELmodel->selected_version();
Description:
	Returns the selected version of the model
=cut
sub selected_version {
	my ($self) = @_;

	if (!defined($self->{_selectedversion})) {
		return "";
	}
	return $self->{_selectedversion};
}

=head3 modification_time
Definition:
	string = FIGMODELmodel->modification_time();
Description:
	Returns the selected version of the model
=cut
sub modification_time {
	my ($self) = @_;
	return $self->ppo()->modificationDate();
}

=head3 gene_reactions
Definition:
	string = FIGMODELmodel->gene_reactions();
Description:
	Returns the number of reactions added by the gap filling
=cut
sub gene_reactions {
	my ($self) = @_;
	return ($self->ppo()->reactions() - $self->ppo()->autoCompleteReactions() - $self->ppo()->spontaneousReactions() - $self->ppo()->gapFillReactions());
}

=head3 total_compounds
Definition:
	string = FIGMODELmodel->total_compounds();
Description:
	Returns the number of compounds in the model
=cut
sub total_compounds {
	my ($self) = @_;
	return $self->ppo()->compounds();
}

=head3 gapfilling_reactions
Definition:
	string = FIGMODELmodel->gapfilling_reactions();
Description:
	Returns the number of reactions added by the gap filling
=cut
sub gapfilling_reactions {
	my ($self) = @_;
	return ($self->ppo()->autoCompleteReactions()+$self->ppo()->gapFillReactions());
}

=head3 gapfilled_roles
Definition:
	{}:Output = FBAMODEL->gapfilled_roles->({})
	Output:{string:role name => [string]:gapfilled reactions}
Description:
	Returns a hash where the keys are gapfilled roles, and the values are arrays of gapfilled reactions associated with each role.
=cut
sub gapfilled_roles {
	my ($self) = @_;
	my $result;
	my $rxnRoleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
	my $tbl = $self->reaction_table();
	if (defined($rxnRoleHash) && defined($tbl)) {
		for (my $i=0; $i < $tbl->size();$i++) {
			my $row = $tbl->get_row($i);
			if ((!defined($row->{"ASSOCIATED PEG"}) || $row->{"ASSOCIATED PEG"}->[0] =~ m/AUTO|GAP/) && defined($rxnRoleHash->{$row->{LOAD}->[0]})) {
				foreach my $role (keys(%{$rxnRoleHash->{$row->{LOAD}->[0]}})) {
					push(@{$result->{$rxnRoleHash->{$row->{LOAD}->[0]}->{$role}->name()}},$row->{LOAD}->[0]);
				}
			}
		}
	}
	return $result;
}

=head3 total_reactions
Definition:
	string = FIGMODELmodel->total_reactions();
Description:
	Returns the total number of reactions in the model
=cut
sub total_reactions {
	my ($self) = @_;
	return $self->ppo()->reactions();
}

=head3 model_genes
Definition:
	string = FIGMODELmodel->model_genes();
Description:
	Returns the number of genes mapped to one or more reactions in the model
=cut
sub model_genes {
	my ($self) = @_;
	return $self->ppo()->associatedGenes();
}

=head3 class
Definition:
	string = FIGMODELmodel->class();
Description:
	Returns the class of the model: gram positive, gram negative, other
=cut
sub class {
	my ($self) = @_;
	return $self->ppo()->cellwalltype();
}

sub autocompleteMedia {
	my ($self,$newMedia) = @_;
	if (defined($newMedia)) {
		return $self->ppo()->autoCompleteMedia($newMedia);
	}
	return $self->ppo()->autoCompleteMedia();
}

sub biomassReaction {
	my ($self,$newBiomass) = @_;
	if (!defined($newBiomass) || $newBiomass eq $self->ppo()->biomassReaction()) {
		return $self->ppo()->biomassReaction();	
	}
	
	my $bioobj = $self->db()->get_object("bof",{id=>$newBiomass});
	if (!defined($bioobj)) {
		ModelSEED::FIGMODEL::FIGMODELWARNING("Could not find new biomass reaction ".$newBiomass);
		return $self->ppo()->biomassReaction();
	}
	my $oldBiomass = $self->ppo()->biomassReaction();
	if ($oldBiomass =~ m/bio\d+/) {
		my $rxnmdl = $self->rxnmdl();
		for (my $i=0; $i < @{$rxnmdl}; $i++) {
			if ($rxnmdl->[$i]->REACTION() eq $self->ppo()->biomassReaction()) {
				$rxnmdl->[$i]->REACTION($newBiomass);
			}
		}
	} else {
		$self->db()->create_object("rxnmdl",{
			MODEL=>$self->id(),
			REACTION=>$newBiomass,
			compartment=>"c",
			confidence=>1,
			pegs=>"SPONTANEOUS",
			directionality=>"=>"
		})
	}
	return $self->ppo()->biomassReaction($newBiomass);
}

=head3 biomassObject
Definition:
	PPObof:biomass object = FIGMODELmodel->biomassObject();
Description:
	Returns the PPO object for the biomass reaction of the model
=cut
sub biomassObject {
	my ($self) = @_;
	if (!defined($self->{_biomassObj})) {
		$self->{_biomassObj} = $self->figmodel()->database()->get_object("bof",{id => $self->ppo()->biomassReaction()});
	}
	return $self->{_biomassObj};
}

=head3 type
Definition:
	mgmodel/model = FIGMODELmodel->type();
Description:
	Returns the type of ppo object that the current model represents
=cut
sub type {
	my ($self) = @_;
	if (!defined($self->{_type})) {
		$self->{_type} = "model";
		if ($self->source() =~ m/MGRAST/) {
			$self->{_type} = "mgmodel";
		}
	}
	return $self->{_type};
}

=head3 growth
Definition:
	double = FIGMODELmodel->growth();
Description:
=cut
sub growth {
	my ($self,$inGrowth) = @_;
	if (!defined($inGrowth)) {
		return $self->ppo()->growth();	
	} else {
		return $self->ppo()->growth($inGrowth);	
	}
}

=head3 cellwalltype
Definition:
	string = FIGMODELmodel->cellwalltype();
Description:
=cut
sub cellwalltype {
	my ($self,$inType) = @_;
	if (!defined($inType)) {
		return $self->ppo()->cellwalltype();	
	} else {
		return $self->ppo()->cellwalltype($inType);	
	}
}

=head3 autoCompleteMedia
Definition:
	string = FIGMODELmodel->autoCompleteMedia();
Description:
=cut
sub autoCompleteMedia {
	my ($self,$inType) = @_;
	if (!defined($inType)) {
		return $self->ppo()->autoCompleteMedia();	
	} else {
		return $self->ppo()->autoCompleteMedia($inType);	
	}
}

=head3 noGrowthCompounds
Definition:
	string = FIGMODELmodel->noGrowthCompounds();
Description:
=cut
sub noGrowthCompounds {
	my ($self,$inCompounds) = @_;
	if (!defined($inCompounds)) {
		return $self->ppo()->noGrowthCompounds();	
	} else {
		return $self->ppo()->noGrowthCompounds($inCompounds);	
	}
}

=head3 taxonomy
Definition:
	string = FIGMODELmodel->taxonomy();
Description:
	Returns model taxonomy or biome if this is an metagenome model
=cut
sub taxonomy {
	my ($self) = @_;
	return $self->genomeObj()->taxonomy();
}

=head3 genome_size
Definition:
	string = FIGMODELmodel->genome_size();
Description:
	Returns size of the modeled genome in KB
=cut
sub genome_size {
	my ($self) = @_;
	return $self->genomeObj()->size();
}

=head3 genome_genes
Definition:
	string = FIGMODELmodel->genome_genes();
Description:
	Returns the number of genes in the modeled genome
=cut
sub genome_genes {
	my ($self) = @_;
	return $self->genomeObj()->totalGene();
}

=head3 update_stats_for_gap_filling
Definition:
	{string => [string]} = FIGMODELmodel->update_stats_for_gap_filling(int::gapfill time);
Description:
=cut
sub update_stats_for_gap_filling {
	my ($self,$gapfilltime) = @_;
	$self->ppo()->autoCompleteTime($gapfilltime);
	$self->ppo()->autocompleteDate(time());
	$self->ppo()->modificationDate(time());
	my $version = $self->ppo()->autocompleteVersion();
	$self->ppo()->autocompleteVersion($version+1);
}

=head3 update_stats_for_build
Definition:
	{string => [string]} = FIGMODELmodel->update_stats_for_build();
Description:
=cut
sub update_stats_for_build {
	my ($self) = @_;
	$self->ppo()->builtDate(time());
	$self->ppo()->modificationDate(time());
	my $version = $self->ppo()->version();
	$self->ppo()->version($version+1);
}



=head3 update_model_stats
Definition:
	FIGMODELmodel->update_model_stats();
Description:
=cut
sub update_model_stats {
	my ($self) = @_;
	my $rxnmdl = $self->rxnmdl();
	my $cpdtbl = $self->compound_table();
	my $counts = {
		spontaneous => 0,
		growmatch => 0,
		autocompletion => 0,
		biolog => 0,
		reactions => (@{$rxnmdl}-1),
		genes => 0,	
		transporters => 0
	};
	my $rxnHash = $self->figmodel()->database()->get_object_hash({
		type => "reaction",
		attribute => "id",
		useCache => 1
	});
	my $geneHash;
	for (my $i=0; $i < @{$rxnmdl}; $i++) {
		my $pegs = $self->figmodel()->get_reaction()->parseGeneExpression({
			expression => $rxnmdl->[$i]->pegs()
		});
		if (defined($pegs->{genes}->[0])) {
			my $lcgene = lc($pegs->{genes}->[0]);
			if ($lcgene eq "biolog") {
				$counts->{biolog}++;
			}elsif ($lcgene eq "growmatch") {
				$counts->{growmatch}++;
			}elsif ($lcgene eq "spontaneous") {
				$counts->{spontaneous}++;
			}elsif ($lcgene eq "unknown" || $lcgene eq "universal" || $lcgene eq "gap" || $lcgene eq "autocompletion") {
				$counts->{autocompletion}++;
			}elsif ($lcgene eq "biolog") {
				$counts->{biolog}++;
			} else {
				for (my $j=0; $j < @{$pegs->{genes}}; $j++) {
					push(@{$geneHash->{$pegs->{genes}->[$j]}},$rxnmdl->[$i]->REACTION());
				}	
			}
		}
		if (defined($rxnHash->{$rxnmdl->[$i]->REACTION()}) && $rxnHash->{$rxnmdl->[$i]->REACTION()}->[0]->equation() =~ m/\[e\]/) {
			$counts->{transporters}++;
		}
	}
	$counts->{genes} = keys(%{$geneHash});
	$self->ppo()->reactions($counts->{reactions});
	$self->ppo()->compounds($cpdtbl->size());
	$self->ppo()->associatedGenes($counts->{genes});
	$self->ppo()->spontaneousReactions($counts->{spontaneous});
	$self->ppo()->gapFillReactions($counts->{growmatch});
	$self->ppo()->biologReactions($counts->{biolog});
	$self->ppo()->transporters($counts->{transporters});
	$self->ppo()->autoCompleteReactions($counts->{autocompletion});
	$self->ppo()->associatedSubsystemGenes($counts->{genes});
	#Setting the model class
	my $class = "";
	for (my $i=0; $i < @{$self->figmodel()->config("class list")}; $i++) {
		if (defined($self->figmodel()->config($self->figmodel()->config("class list")->[$i]))) {
			if (defined($self->figmodel()->config($self->figmodel()->config("class list")->[$i])->{$self->id()})) {
				$class = $self->figmodel()->config("class list")->[$i];
				last;
			}
			if ($class eq "" && defined($self->figmodel()->config($self->figmodel()->config("class list")->[$i])->{$self->genome()})) {
				$class = $self->figmodel()->config("class list")->[$i];
			}
		}
	}
	if (lc($self->genome()) eq "none" || lc($self->genome()) eq "unknown") {
		$class = "unknown";
	} elsif ($class eq "" && defined($self->genomeObj()->genome_stats())) {
		$class = $self->genomeObj()->genome_stats()->class();
	}
	if ($class eq "") {
		$class = "unknown";   
	}
	$self->ppo()->cellwalltype($class);
}

=head3 printInactiveReactions
Definition:
	{error => string} = FIGMODELmodel->printInactiveReactions({
		filename => string,
		unorderedList => undef,
		priorityList => undef
	});
Description:
=cut
sub printInactiveReactions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{
		unorderedList => undef,
		priorityList => undef
	});
	if (defined($args->{error})) {return $self->error_message({function => "printInactiveReactions",args => $args});}
	#Loading the unordered list if one has not been provided
	if (!defined($args->{unorderedList})) {
		my $obj = $self->figmodel()->database()->get_object("mdlfva",{MODEL=>$self->id(),MEDIA=>"Complete",parameters=>"NG;DR:bio00001;"});
		$args->{unorderedList} = [split(/;/,$obj->inactive().$obj->dead())];
	}
	#Loading the priority list if one has not been provided
	if (!defined($args->{priorityList})) {
		$args->{priorityList} = $self->figmodel()->database()->load_single_column_file($self->figmodel()->config("reaction priority list")->[0],"\t");
	}
	#Loading the unordered list into a hash
	my $hash;
	for(my $j=0; $j < @{$args->{unorderedList}}; $j++) {
		if (length($args->{unorderedList}->[$j]) > 0) {
			$hash->{$args->{unorderedList}->[$j]} = 0;
		}
	}
	if (defined($hash->{$self->ppo()->biomassReaction()})) {
		delete	 $hash->{$self->ppo()->biomassReaction()};
	}
	#Printing the ordered list
	for(my $j=0; $j < @{$args->{priorityList}}; $j++) {
		if (defined($hash->{$args->{priorityList}->[$j]})) {
			push(@{$args->{finalList}},$args->{priorityList}->[$j]);
			$hash->{$args->{priorityList}->[$j]} = 1;
		}
	}
	foreach my $rxn (keys(%{$hash})) {
		if ($hash->{$rxn} == 0) {
			push(@{$args->{finalList}},$rxn);
			$hash->{$rxn} = 1;
		}
	}
	push(@{$args->{finalList}},$self->ppo()->biomassReaction());
	$self->figmodel()->database()->print_array_to_file($args->{filename},$args->{finalList});
	return $args;
}

=head3 completeGapfilling
Definition:
	{error => string} = FIGMODELmodel->completeGapfilling({
		gapfillCoefficientsFile => "NONE",
		inactiveReactionBonus => 0.1,
		drainBiomass => "bio00001",
		media => "Complete"
	});
Description:
=cut
sub completeGapfilling {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		startFresh => 1,
		problemDirectory => undef,#Name of the job directory, which plays a role in check pointing the complete gapfilling pipeline
		rungapfilling=>1,
		removeGapfillingFromModel => 1,
		gapfillCoefficientsFile => "NONE",
		inactiveReactionBonus => 100,
		fbaStartParameters => {
			media => "Complete",
		},
		iterative => 1,
		adddrains => 0,
		testsolution => 1,
		globalmessage => 0
	});
	my $start = time();
	my $fbaObj = $self->fba();
	#Creating the problem directory
	if (defined($args->{problemdirectory}) && $args->{problemdirectory} eq "MODELID") {
   		$args->{problemdirectory} = "Gapfilling-".$self->id();
   	}
	if (!defined($args->{problemDirectory})) {
		$args->{problemDirectory} = $fbaObj->filename();
	}
	$fbaObj->filename($args->{problemDirectory});
	print "Creating problem directory: ",$fbaObj->filename(),"\n";

	$fbaObj->makeOutputDirectory({deleteExisting => $args->{startFresh}});
	#Printing list of inactive reactions
	if ($args->{iterative} == 0) {
		my $list = [$self->ppo()->biomassReaction()];
		$self->figmodel()->database()->print_array_to_file($fbaObj->directory()."/InactiveModelReactions.txt",$list);
	}
	print "Creating list of inactive reactions: ",$fbaObj->directory()."/InactiveModelReactions.txt\n";
	my $results;
	if (!-e $fbaObj->directory()."/InactiveModelReactions.txt") {
		$args->{fbaStartParameters}->{options}->{freeGrowth} = 1;
		$results = $self->runFBAStudy({
			fbaStartParameters => $args->{fbaStartParameters},
			setupParameters => {
				function => "setTightBounds",
				arguments => {variables => ["FLUX"]}	
			},
			problemDirectory => undef,
			parameterFile => "FVAParameters.txt",
			startFresh => 0,
			removeGapfillingFromModel => $args->{removeGapfillingFromModel},
			forcePrintModel => 1,
			runProblem=>1
		});
		ModelSEED::FIGMODEL::FIGMODELERROR("Could not calculate inactive reactions") if (!defined($results->{tb}));
		delete $args->{fbaStartParameters}->{options}->{freeGrowth};
		my $inactive;
		foreach my $obj (keys(%{$results->{tb}})) {
			if ($obj =~ m/([rb][xi][no]\d+)/ && $results->{tb}->{$obj}->{min} > -0.0000001 && $results->{tb}->{$obj}->{max} < 0.0000001) {
				push(@{$inactive},$obj);
			}
		}
		$self->printInactiveReactions({
			filename => $fbaObj->directory()."/InactiveModelReactions.txt",
			unorderedList => $inactive,
		});
	}
	print "Printing gapfilling parameters in : ",$fbaObj->directory()."/CompleteGapfillingParameters.txt\n";
	#Printing gapfilling parameters
	if (!-e $fbaObj->directory()."/CompleteGapfillingParameters.txt") {
		if ($args->{adddrains} == 1) {
			$args->{fbaStartParameters}->{options}->{adddrains} = 1;
		}
		$args->{fbaStartParameters}->{parameters}->{"create file on completion"} = "GapfillingComplete.txt";
		print "Running runFBAStudy\n";
		$results = $self->runFBAStudy({
			fbaStartParameters => $args->{fbaStartParameters},
			setupParameters => {
				function => "setCompleteGapfillingStudy",
				arguments => {
					minimumFluxForPositiveUseConstraint=> "0.01",
					gapfillCoefficientsFile => $args->{gapfillCoefficientsFile},
					inactiveReactionBonus => $args->{inactiveReactionBonus}
				}	
			},
			problemDirectory => $args->{problemDirectory},
			parameterFile => "CompleteGapfillingParameters.txt",
			startFresh => 0,
			removeGapfillingFromModel => $args->{removeGapfillingFromModel},
			forcePrintModel => 1,
			runProblem=> $args->{rungapfilling}
		});
		delete $args->{fbaStartParameters}->{options}->{adddrains};
		delete $args->{fbaStartParameters}->{parameters}->{"create file on completion"};
		print "Finished runFBAStudy\n";
	}
	#Exiting now if the user did not request that the gapfilling be run
	if ($args->{rungapfilling} == 0) {
		return {
			status=>"Success",
			problemDirectory => $args->{problemDirectory}
		};
	}
	#Checking that a gapfilling solution was printed
	if (!-e $fbaObj->directory()."/GapfillingComplete.txt") {
		ModelSEED::FIGMODEL::FIGMODELERROR("Gapfilling of model ".$self->id()." failed!");	
	}
	#Loading the gapfilling solution into the model
	$results = $self->integrateGapfillingSolution({
		directory => $fbaObj->directory(),
		gapfillResults => $results
	});
	print "Calculting the growth with which to test the model\n";
	#Calculating the growth to test the model
	my $growthResults = $self->fbaCalculateGrowth({
		fbaStartParameters => $args->{fbaStartParameters}
	});
	#Printing the growth message
	if ($args->{globalmessage} == 1) {
		my $message = "Growth:".$self->ppo()->growth().";Additions:".$results->{additions}.";Gapfilling:".$results->{gaps};
		$self->globalMessage({
			function => "completeGapfilling",
			package => "FIGMODELmodel",
			message => $message,
			thread => "completeGapfilling",
		});
	}
	#Assessing the gapfilling solution
	if ($args->{testsolution} == 1) {
		$results = $self->fbaTestGapfillingSolution({
			fbaStartParameters => {
				media => "Complete",
				drnRxn => $args->{drnRxn}	
			},
			problemDirectory => $self->id()."GFT"
		});
		if (defined($results->{fbaObj})) {
			$results->{fbaObj}->clearOutput();
		}
	}
	$self->set_status(2,"New gapfilling complete");
	$self->update_model_stats();
	#$self->update_stats_for_gap_filling(time() - $start);
	#$self->figmodel()->processModel();
	return $results;
}

=head3 integrateGapfillingSolution
Definition:
	Results:{} = FIGMODELmodel->integrateGapfillingSolution({
		directory => string:?,
		gapfillResults => {}
	});
Description:
=cut
sub integrateGapfillingSolution {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["directory","gapfillResults"],{});
	my $output = {success => 1};
	#Copying the gapfilling solution to the model directory
	if (-e $self->directory()."/GapfillingOutput.txt") {
		my $oldFile = $self->figmodel()->database()->load_single_column_file($self->directory()."/GapfillingOutput.txt","");
		if (@{$oldFile} >= 2) {
			$self->figmodel()->database()->print_array_to_file($self->directory()."/GapfillingOutput.bkup",$oldFile,1);
		}
	}
	system("cp ".$args->{directory}."/CompleteGapfillingOutput.txt ".$self->directory()."/GapfillingOutput.txt");
	my $solutionHash;
	foreach my $rxn (keys(%{$args->{gapfillResults}})) {
		if (defined($args->{gapfillResults}->{$rxn}->{gapfilled}->[0])) {
			for (my $i=0; $i < @{$args->{gapfillResults}->{$rxn}->{gapfilled}}; $i++) {
				if ($args->{gapfillResults}->{$rxn}->{gapfilled}->[$i] =~ m/(.)(rxn\d+)/) {
					my $gapRxn = $2;
					my $gapSign = $1;
					my $sign = "=>";
					if ($gapSign eq "-") {
						$sign = "<=";
					}
					if (defined($solutionHash->{$gapRxn}->{sign}) && $solutionHash->{$gapRxn}->{sign} ne $sign) {
						$sign = "<=>";
					}
					$solutionHash->{$gapRxn}->{sign} = $sign;
					push(@{$solutionHash->{$gapRxn}->{target}},$rxn);
					if (defined($args->{gapfillResults}->{$rxn}->{repaired}->[0])) {
						for (my $j=0; $j < @{$args->{gapfillResults}->{$rxn}->{repaired}}; $j++) {
							if ($args->{gapfillResults}->{$rxn}->{repaired}->[$j] =~ m/(.)(rxn\d+)/) {
								$solutionHash->{$gapRxn}->{repaired}->{$2} = 1;
							}
						}
					}
				}
			}
		}
	}
	return $self->error_message({message => $args->{gapfillResults}->{error},function => "completeGapfilling",args => $args}) if (defined($args->{gapfillResults}->{error}));
	#Loading the reaction table located in the problem directory and adjusting based on the gapfilling solution
	my $rxns = $self->figmodel()->database()->load_table($args->{directory}."/".$self->id().".tbl",";","|",1,["LOAD","ASSOCIATED PEG","COMPARTMENT"]);
	foreach my $rxn (keys(%{$solutionHash})) {
		if ($rxn ne "rxn12985") {
			my $rev = $self->figmodel()->reversibility_of_reaction($rxn);
			if ($solutionHash->{$rxn}->{sign} ne $rev) {
				$solutionHash->{$rxn}->{sign} = "<=>";
			}
			my $target = "None";
			my $repair = "None";
			if (defined($solutionHash->{$rxn}->{target})) {
				$target = join(", ",@{$solutionHash->{$rxn}->{target}});
			}
			if (defined($solutionHash->{$rxn}->{repaired})) {
				$repair = join(", ",keys(%{$solutionHash->{$rxn}->{repaired}}));
			}
			my $row = $rxns->get_table_by_key($rxn,"LOAD")->get_row_by_key("c","COMPARTMENT");
			if (!defined($row)) {
				$rxns->add_row({SUBSYSTEM => ["NONE"],CONFIDENCE => [4],REFERENCE => ["NONE"],NOTES => [],LOAD => [$rxn],DIRECTIONALITY => [$solutionHash->{$rxn}->{sign}],COMPARTMENT => ["c"],"ASSOCIATED PEG" => ["AUTOCOMPLETION"]});
			} else {
				$row->{NOTES}->[0] = "Switched from ".$row->{DIRECTIONALITY}->[0];
				$row->{DIRECTIONALITY}->[0] = "<=>";
			}
		}
	}
	#Saving modified reaction table to the model directory
	my $rxnObjs = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL=>$self->id()});
	my $repRow;
	$output->{additions} = 0;
	$output->{gaps} = 0;
	for (my $i=0; $i < @{$rxnObjs}; $i++) {
		my $row = $rxns->get_table_by_key($rxnObjs->[$i]->REACTION(),"LOAD")->get_row_by_key($rxnObjs->[$i]->compartment(),"COMPARTMENT");
		if (defined($row)) {
			print "Adjusting reaction ".$rxnObjs->[$i]->REACTION()."\n";
			$rxnObjs->[$i]->directionality($row->{DIRECTIONALITY}->[0]);
			my $newpegs = join("|",@{$row->{"ASSOCIATED PEG"}});
			print $newpegs."\t";
			$newpegs =~ s/\\//g;
			print $newpegs."\n";
			$rxnObjs->[$i]->pegs($newpegs);
			$rxnObjs->[$i]->confidence($row->{CONFIDENCE}->[0]);
			$repRow = $rxnObjs->[$i];
			$row->{found} = 1;
			if ($newpegs eq "AUTOCOMPLETION") {
				$output->{gaps}++;
			}
		} else {
			print "Deleting reaction ".$rxnObjs->[$i]->REACTION()."\n";
			$rxnObjs->[$i]->delete();	
		}
	}
	for (my $i=0; $i < $rxns->size(); $i++) {
		my $row = $rxns->get_row($i);
		if (!defined($row->{found}) || $row->{found} != 1) {
			print "Adding reaction ".$row->{LOAD}->[0]."\n";
			$self->figmodel()->database()->create_object("rxnmdl",{
				MODEL=>$self->id(),
				REACTION=>$row->{LOAD}->[0],
				compartment=>$row->{COMPARTMENT}->[0],
				confidence=>$row->{CONFIDENCE}->[0],
				pegs=>join("|",@{$row->{"ASSOCIATED PEG"}}),
				directionality=>$row->{DIRECTIONALITY}->[0]
			});
			$output->{additions}++;
			$output->{gaps}++;
		}
	}
	return $output;
}

=head3 GapFillModel
Definition:
	(success/fail) = FIGMODELmodel->GapFillModel();
Description:
	This function performs an optimization to identify the minimal set of reactions that must be added to a model in order for biomass to be produced by the biomass reaction in the model.
	Before running the gap filling, the existing model is backup in the same directory with the current version numbers appended.
	If the model has been gap filled previously, the previous gap filling reactions are removed prior to running the gap filling again.
=cut
sub GapFillModel {
	my ($self,$donotclear,$createLPFileOnly, $Media) = @_;

	#Setting status of model to gap filling
	my $OrganismID = $self->genome();
	$self->set_status(1,"Auto completion running");
	my $UniqueFilename = $self->figmodel()->filename();
	my $StartTime = time();
	
	#Reading original reaction table
	my $OriginalRxn = $self->reaction_table();
	#Clearing the table
	$self->reaction_table(1);
	#Removing any gapfilling reactions that may be currently present in the model
	if (!defined($donotclear) || $donotclear != 1) {
		my $ModelTable = $self->reaction_table();
		for (my $i=0; $i < $ModelTable->size(); $i++) {
			$ModelTable->get_row($i)->{"DIRECTIONALITY"}->[0] = $self->figmodel()->reversibility_of_reaction($ModelTable->get_row($i)->{"LOAD"}->[0]);
			if (!defined($ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0]) || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] eq "AUTOCOMPLETION" || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] eq "GAP FILLING" || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] =~ m/BIOLOG/ || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] =~ m/GROWMATCH/) {
				$ModelTable->delete_row($i);
				$i--;
			}
		}
		$ModelTable->save();
	}

	#Calling the MFAToolkit to run the gap filling optimization
	if(!defined($Media)) {
		$Media = $self->autocompleteMedia();
	}
	my $lpFileOnlyParameter = 0;
	if (defined($createLPFileOnly) && $createLPFileOnly == 1) {
		$lpFileOnlyParameter = 1;
	}
	if ($Media eq "Complete") {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),undef,["GapFilling"],{
			"Constrain objective to this fraction of the optimal value"=>"0.001",
			"Default min drain flux"=>"-10000",
			"Default max drain flux"=>"10000",
			"MFASolver"=>"CPLEX",
			"Allowable unbalanced reactions"=>$self->config("acceptable unbalanced reactions")->[0],
			"print lp files rather than solve" => $lpFileOnlyParameter,
			"dissapproved compartments"=>$self->config("diapprovied compartments")->[0],
			"Reactions to knockout" => $self->config("permanently knocked out reactions")->[0]
		},"GapFill".$self->id().".log",undef));
	} else {
		#Loading media, changing bounds, saving media as a test media
		my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("Media directory")->[0].$Media.".txt",";","",0,["VarName"]);
		for (my $i=0; $i < $MediaTable->size(); $i++) {
			if ($MediaTable->get_row($i)->{"Min"}->[0] < 0) {
				$MediaTable->get_row($i)->{"Min"}->[0] = -10000;
			}
			if ($MediaTable->get_row($i)->{"Max"}->[0] > 0) {
				$MediaTable->get_row($i)->{"Max"}->[0] = 10000;
			}
		}
		$MediaTable->save($self->config("Media directory")->[0].$UniqueFilename."TestMedia.txt");
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$UniqueFilename."TestMedia",["GapFilling"],{"MFASolver"=>"CPLEX","Allowable unbalanced reactions"=>$self->config("acceptable unbalanced reactions")->[0],"print lp files rather than solve" => $lpFileOnlyParameter,"Default max drain flux" => 0,"dissapproved compartments"=>$self->config("diapprovied compartments")->[0],"Reactions to knockout" => $self->config("permanently knocked out reactions")->[0]},"GapFill".$self->id().".log",undef));
		unlink($self->config("Media directory")->[0].$UniqueFilename."TestMedia.txt");
	}

	#Looking for gapfilling report
	if (!-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingReport.txt") {
		$self->error_message({function => "GapFillModel",message => "no gapfilling solution found!"});
		system($self->figmodel()->config("Model driver executable")->[0]." \"setmodelstatus?".$self->id()."?1?Autocompletion___failed___to___find___solution\"");
		return $self->figmodel()->fail();
	}
	#Loading gapfilling report
	my $gapTbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingReport.txt",";","|",0,undef);
	#Copying gapfilling report to model directory
	system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingReport.txt ".$self->directory()."GapFillingReport.txt");
	#Adding gapfilling solution to model
	for (my $i=0; $i < $gapTbl->size(); $i++) {
		my $row = $gapTbl->get_row($i);
		if (defined($row->{Solutions}->[0])) {
			my $rxnTbl = $self->reaction_table();
			my $solution = $row->{Solutions}->[0];
			my @reactions = split(/,/,$solution);
			for (my $i=0; $i < @reactions; $i++) {
				if ($reactions[$i] =~ m/([\+\-])(rxn\d\d\d\d\d)/) {
					my $sign = $1;
					my $reaction = $2;
					my $rxnRow = $rxnTbl->get_row_by_key($reaction,"LOAD");
					if (defined($rxnRow)) {
						$rxnRow->{"DIRECTIONALITY"}->[0] = "<=>";
					} else {
						my $direction = $self->figmodel()->reversibility_of_reaction($reaction);
						if ($direction ne "<=>") {
							if ($sign eq "-" && $direction eq "=>") {
								 $direction = "<=>";
							} elsif ($sign eq "+" && $direction eq "<=") {
								$direction = "<=>";
							}
						}
						$rxnTbl->add_row({LOAD => [$reaction],DIRECTIONALITY => [$direction],COMPARTMENT => ["c"],"ASSOCIATED PEG" => ["AUTOCOMPLETION"]});
					}
					
					
				}
			}
			$rxnTbl->save();
			last;
		}
	}
	$OriginalRxn->save($self->directory()."OriginalModel-".$self->id()."-".$UniqueFilename.".txt");
	my $ElapsedTime = time() - $StartTime;
	if (!defined($donotclear) || $donotclear != 1) {
		system($self->figmodel()->config("Model driver executable")->[0]." \"updatestatsforgapfilling?".$self->id()."?".$ElapsedTime."\"");
	}
	#Queueing up model change and gapfilling dependancy functions
	system($self->figmodel()->config("Model driver executable")->[0]." \"calculatemodelchanges?".$self->id()."?".$UniqueFilename."?Autocompletion\"");
	system($self->figmodel()->config("Model driver executable")->[0]." \"getgapfillingdependancy?".$self->id()."\"");
	system($self->figmodel()->config("Model driver executable")->[0]." \"setmodelstatus?".$self->id()."?1?Autocompletion___successfully___finished\"");
	system($self->figmodel()->config("Model driver executable")->[0]." \"processmodel?".$self->id()."\"");
	return $self->figmodel()->success();
}

=head3 processModel
Definition:
	FIGMODELmodel->processModel();
Description:
=cut
sub processModel {
	my ($self) = @_;
	if (-e $self->directory()) {
		mkdir $self->directory();
	}
	if (-e $self->directory()."ReactionClassification-".$self->id().".tbl") {
		unlink $self->directory()."ReactionClassification-".$self->id().".tbl";
	}
	if (-e $self->directory()."CompoundClassification-".$self->id().".tbl") {
		unlink $self->directory()."CompoundClassification-".$self->id().".tbl";
	}
	if (-e $self->directory()."EssentialGenes-".$self->id().".tbl") {
		unlink $self->directory()."EssentialGenes-".$self->id().".tbl";
	}
	if (-e $self->directory()."FBA-".$self->id().".lp") {
		unlink $self->directory()."FBA-".$self->id().".lp";
	}
	if (-e $self->directory()."FBA-".$self->id().".key") {
		unlink $self->directory()."FBA-".$self->id().".key";
	}
	if (-e $self->directory().$self->id().".xml") {
		unlink $self->directory().$self->id().".xml";
	}
	if (-e $self->directory().$self->id().".lp") {
		unlink $self->directory().$self->id().".lp";
	}
	if (-e $self->directory()."ReactionTbl-".$self->id().".tbl") {
		unlink $self->directory()."ReactionTbl-".$self->id().".tbl";
	}
	if (-e $self->directory()."ReactionTbl-".$self->id().".txt") {
		unlink $self->directory()."ReactionTbl-".$self->id().".txt";
	}
	$self->create_model_rights();
	$self->update_model_stats();
	$self->PrintSBMLFile();
	#$self->PrintModelLPFile();
	#$self->PrintModelLPFile(1);
	#$self->run_default_model_predictions();
}

=head3 load_scip_gapfill_results
Definition:
	FIGMODELmodel->load_scip_gapfill_results(string:filename);
Description:
	
=cut

sub load_scip_gapfill_results {
	my ($self,$filename) = @_;
	my $time = 0;
	my $gap = 0;
	my $objective = 0;
	my $start = 0;
	my $ReactionList;
	my $DirectionList;
	my $fileLines = $self->figmodel()->database()->load_single_column_file($filename);
	for (my $i=0; $i < @{$fileLines}; $i++) {
		if ($fileLines->[$i] =~ m/^\s*(\d+)m\|.+\s(.+)%/) {
			$time = 60*$1;
			$gap = $2;
		} elsif ($fileLines->[$i] =~ m/^\s*(\d+)s\|.+\s(.+)%/) {
			$time = $1;
			$gap = $2;
		} elsif ($fileLines->[$i] =~ m/solving\swas\sinterrupted/ && $gap eq "0") {
			$gap = 1;
		} elsif ($fileLines->[$i] =~ m/^Solving\sTime\s\(sec\)\s:\s*(\S+)/) {
			$time = $1;
		} elsif ($fileLines->[$i] =~ m/^Gap.+:\s*([\S]+)\s*\%/) {	
			$gap = $1;
		} elsif ($fileLines->[$i] =~ m/^objective\svalue:\s*([\S]+)/) {
			$objective = $1;
			$start = 1;
		} elsif ($start == 1 && $fileLines->[$i] =~ m/\(obj:([\S]+)\)/) {
			my $coef = $1;
			if ($coef ne "0") {
				my $ID = "";
				my $Sign = "<=>";
				if ($fileLines->[$i] =~ m/^FFU_(rxn\d\d\d\d\d)/) {
					$Sign = "=>";
					$ID = $1;
				} elsif ($fileLines->[$i] =~ m/^RFU_(rxn\d\d\d\d\d)/) {
					$Sign = "<=";
					$ID = $1;
				}
				if ($ID ne "") {
					if ($self->figmodel()->reversibility_of_reaction($ID) ne $Sign) {
						$Sign = "<=>";
					}
					push(@{$DirectionList},$Sign);
					push(@{$ReactionList},$ID);
				}
			}
		}
	}
	$self->ppo()->autocompletionDualityGap($gap);
	$self->ppo()->autocompletionObjective($objective);
	$self->ppo()->autoCompleteTime($time);
	if (defined($ReactionList) && @{$ReactionList} > 0) {
		my $OriginalRxn = $self->reaction_table();
		$self->figmodel()->IntegrateGrowMatchSolution($self->id(),undef,$ReactionList,$DirectionList,"AUTOCOMPLETION",0,1);
		#Updating model stats with gap filling results
		$self->reaction_table(1);
		$self->calculate_model_changes($OriginalRxn,"AUTOCOMPLETION");
		#Determining why each gap filling reaction was added
		$self->figmodel()->IdentifyDependancyOfGapFillingReactions($self->id(),$self->autocompleteMedia());
		if ($self->id() !~ m/MGRast/) {
			$self->update_stats_for_gap_filling($time);
		} else {
			$self->update_model_stats();
		}
		#Printing the updated SBML file
		$self->PrintSBMLFile();
		$self->PrintModelLPFile($self->id());
		$self->set_status(1,"Auto completion successfully finished");
		$self->run_default_model_predictions();
		return $self->figmodel()->success();
	} else {
		$self->set_status(1,"No autocompletion soluion found. Autocompletion time extended.");
	}
	return $self->figmodel()->fail();	
}

=head3 compare_reaction_tables
Definition:
	FIGMODELTable:changes = FIGMODELFIGMODELmodel->compare_reaction_tables({changeTbl => FIGMODELTable:existing change table,
																			changeTblFile => string:filename for existing change table,
																			compareTbl => FIGMODELTable:table to compare against,
																			note => string:modification note});
Description:
=cut
sub compare_two_reaction_tables {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["compareTbl"],{changeTbl => undef,changeTblFile => undef,note => "NONE"});
	if (defined($args->{error})) {return {error => $args->{error}};}
	#Loading the existing change table if provided, otherwise creating new change table
	my $changeTbl;
	if (defined($args->{changeTbl})) {
		$changeTbl = $args->{changeTbl};
	} elsif (defined($args->{changeTblFile})) {
		$changeTbl = $self->figmodel()->database()->load_table($self->directory().$args->{changeTblFile},"\t","|",0,["Reaction","ChangeType"]);
	} else {
		$changeTbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Direction","Compartment","Genes","ChangeType","Note","ChangeTime"],"Temp.txt",["Reaction","ChangeType"],"\t","|",undef);
	}
	my $rxnTbl = $self->reaction_table();
	my $cmpTbl = $args->{compareTbl};
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		my $row = $rxnTbl->get_row($i);
		my $orgRow = $cmpTbl->get_row_by_key($row->{LOAD}->[0],"LOAD");
		if (!defined($orgRow)) {
			$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Reaction added"],Note => [$args->{note}],ChangeTime => time()});
		} else {
			if ($row->{DIRECTIONALITY}->[0] ne $orgRow->{DIRECTIONALITY}->[0]) {
				$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Directionality change(".$orgRow->{DIRECTIONALITY}->[0].")"],Note => [$args->{note}],ChangeTime => time()});
			}
			if ($row->{COMPARTMENT}->[0] ne $orgRow->{COMPARTMENT}->[0]) {
				$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Compartment change(".$orgRow->{COMPARTMENT}->[0].")"],Note => [$args->{note}],ChangeTime => time()});
			}
			if ($row->{COMPARTMENT}->[0] ne $orgRow->{COMPARTMENT}->[0]) {
				$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Compartment change(".$orgRow->{COMPARTMENT}->[0].")"],Note => [$args->{note}],ChangeTime => time()});
			}
			if (defined($row->{"ASSOCIATED PEG"})) {
				for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
					my $match = 0;
					if (defined($orgRow->{"ASSOCIATED PEG"})) {
						for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
							if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
								$match = 1;	
							}
						}
					}
					if ($match == 0) {
						$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["GPR added(".$row->{"ASSOCIATED PEG"}->[$j].")"],Note => [$args->{note}],ChangeTime => time()});
					}
				}
			}
			if (defined($orgRow->{"ASSOCIATED PEG"})) {
				for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
					my $match = 0;
					if (defined($row->{"ASSOCIATED PEG"})) {
						for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
							if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
								$match = 1;
							}
						}
					}
					if ($match == 0) {
						$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["GPR removed(".$orgRow->{"ASSOCIATED PEG"}->[$k].")"],Note => [$args->{note}],ChangeTime => time()});
					}
				}
			}
		}
	}
	#Looking for removed reactions
	for (my $i=0; $i < $cmpTbl->size(); $i++) {
		my $row = $cmpTbl->get_row($i);
		my $orgRow = $rxnTbl->get_row_by_key($row->{LOAD}->[0],"LOAD");
		if (!defined($orgRow)) {
			$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Reaction removed"],Note => [$args->{note}],ChangeTime => time()});
		}
	}
	return $changeTbl;
}

=head3 calculate_model_changes
Definition:
	FIGMODELmodel->calculate_model_changes(FIGMODELTable:original reaction table,string:modification cause);
Description:
	
=cut

sub calculate_model_changes {
	my ($self,$originalReactions,$cause,$tbl,$version,$filename) = @_;
	my $modTime = time();
	if (!defined($version)) {
		$version = $self->selected_version();
	}
	if (defined($filename) && !defined($originalReactions) && -e $self->directory()."OriginalModel-".$self->id()."-".$filename.".txt") {
		$originalReactions = $self->figmodel()->database()->load_table($self->directory()."OriginalModel-".$self->id()."-".$filename.".txt",";","|",1,["LOAD","ASSOCIATED PEG"]);
	}
	my $user = $self->figmodel()->user();
	#Getting the current reaction table if not provided at input
	if (!defined($tbl)) {
		$tbl = $self->reaction_table();
	}
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		my $orgRow = $originalReactions->get_row_by_key($row->{LOAD}->[0],"LOAD");
		if (!defined($orgRow)) {
		} else {
			my $geneChanges;
			my $directionChange = $row->{"DIRECTIONALITY"}->[0];
			if ($orgRow->{"DIRECTIONALITY"}->[0] ne $row->{"DIRECTIONALITY"}->[0]) {
				$directionChange = $orgRow->{"DIRECTIONALITY"}->[0]."|".$row->{"DIRECTIONALITY"}->[0];
			}
			for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
				my $match = 0;
				if (defined($orgRow->{"ASSOCIATED PEG"})) {
					for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
						if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
							$match = 1;	
						}
					}
				}
				if ($match == 0) {
					push(@{$geneChanges},"Added ".$row->{"ASSOCIATED PEG"}->[$j]);
				}
			}
			if (defined($orgRow->{"ASSOCIATED PEG"})) {
				for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
					my $match = 0;
					if (defined($row->{"ASSOCIATED PEG"})) {
						for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
							if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
								$match = 1;
							}
						}
					}
					if ($match == 0) {
						push(@{$geneChanges},"Removed ".$orgRow->{"ASSOCIATED PEG"}->[$k]);
					}
				}
			}
		}
	}
	#Deleting the file with the old reactions
	if (defined($filename) && -e $self->directory()."OriginalModel-".$self->id()."-".$filename.".txt") {
		unlink($self->directory()."OriginalModel-".$self->id()."-".$filename.".txt");
	}
}

=head3 GapGenModel
Definition:
	FIGMODELmodel->GapGenModel();
Description:
	Runs the gap generation algorithm to correct a single false positive prediction. Results are loaded into a table.
=cut

sub GapGenModel {
	my ($self,$Media,$KOList,$NoKOList,$Experiment,$SolutionLimit) = @_;
	
	#Enforcing nonoptional arguments
	if (!defined($Media)) {
		return undef;
	}
	if (!defined($KOList)) {
		$KOList->[0] = "none";
	}
	if (!defined($NoKOList)) {
		$NoKOList->[0] = "none";
	}
	if (!defined($Experiment)) {
		$Experiment= "ReactionKO";
	}
	if (!defined($SolutionLimit)) {
		$SolutionLimit = "10";
	}
	
	#Translating the KO lists into arrays
	if (ref($KOList) ne "ARRAY") {
		my $temp = $KOList;
		$KOList = ();
		push(@{$KOList},split(/[,;]/,$temp));	
	}
	my $noKOHash;
	if (defined($NoKOList) && ref($NoKOList) ne "ARRAY") {
		my $temp = $NoKOList;
		$NoKOList = ();
		push(@{$NoKOList},split(/[,;]/,$temp));
		foreach my $rxn (@{$NoKOList}) {
			$noKOHash->{$rxn} = 1;
		}
	}
	
	#Checking if solutions exist for the input parameters
	$self->aquireModelLock();
	my $tbl = $self->load_model_table("GapGenSolutions");
	my $solutionRow = $tbl->get_table_by_key($Experiment,"Experiment")->get_table_by_key($Media,"Media")->get_row_by_key(join(",",@{$KOList}),"KOlist");
	my $solutions;
	if (defined($solutionRow)) {
		#Checking if any solutions conform to the no KO list
		foreach my $solution (@{$solutionRow->{Solutions}}) {
			my @reactions = split(/,/,$solution);
			my $include = 1;
			foreach my $rxn (@reactions) {
				if ($rxn =~ m/(rxn\d\d\d\d\d)/) {
					if (defined($noKOHash->{$1})) {
						$include = 0;
					}
				}
			}
			if ($include == 1) {
				push(@{$solutions},$solution);
			}
		}
	} else {
		$solutionRow = {Media => [$Media],Experiment => [$Experiment],KOlist => [join(",",@{$KOList})]};
		$tbl->add_row($solutionRow);
		$self->figmodel()->database()->save_table($tbl);
	}
	$self->releaseModelLock();
	
	#Returning solution list of solutions were found
	if (defined($solutions) && @{$solutions} > 0) {
		return $solutions;
	}
	
	#Getting unique filename
	my $Filename = $self->figmodel()->filename();

	#Running the gap generation
	system($self->figmodel()->GenerateMFAToolkitCommandLineCall($Filename,$self->id().$self->selected_version(),$Media,["GapGeneration"],{"Recursive MILP solution limit" => $SolutionLimit ,"Reactions that should always be active" => join(";",@{$NoKOList}),"Reactions to knockout" => join(";",@{$KOList}),"Reactions that are always blocked" => "none"},"Gapgeneration-".$self->id().$self->selected_version()."-".$Filename.".log",undef,undef));
	my $ProblemReport = $self->figmodel()->LoadProblemReport($Filename);
	if (!defined($ProblemReport)) {
		return $self->error_message({function => "GapGenModel",message => "No problem report;".$Filename.";".$self->id().$self->selected_version().";".$Media.";".$KOList.";".$NoKOList});
	}
	
	#Clearing the output folder and log file
	$self->figmodel()->clearing_output($Filename,"Gapgeneration-".$self->id().$self->selected_version()."-".$Filename.".log");
	
	#Saving the solution
	$self->aquireModelLock();
	$tbl = $self->load_model_table("GapGenSolutions");
	$solutionRow = $tbl->get_table_by_key($Experiment,"Experiment")->get_table_by_key($Media,"Media")->get_row_by_key(join(",",@{$KOList}),"KOlist");
	for (my $j=0; $j < $ProblemReport->size(); $j++) {
		if ($ProblemReport->get_row($j)->{"Notes"}->[0] =~ m/^Recursive\sMILP\s([^)]+)/) {
			my @SolutionList = split(/\|/,$1);
			for (my $k=0; $k < @SolutionList; $k++) {
				if ($SolutionList[$k] =~ m/(\d+):(.+)/) {
					push(@{$solutionRow->{Solutions}},$2);
					push(@{$solutions},$2);
				}
			}
		}
	}
	$self->figmodel()->database()->save_table($tbl);
	$self->releaseModelLock();
	
	return $solutions;
}

=head3 datagapfill
Definition:
	success()/fail() = FIGMODELmodel->datagapfill();
Description:
	Run gapfilling on the input run specifications
=cut
sub datagapfill {
	my ($self,$GapFillingRunSpecs,$TansferFileSuffix) = @_;
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($GapFillingRunSpecs) && @{$GapFillingRunSpecs} > 0) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id().$self->selected_version(),"NoBounds",["GapFilling"],{"Reactions to knockout" => $self->config("permanently knocked out reactions")->[0],"Gap filling runs" => join(";",@{$GapFillingRunSpecs})},"GapFilling-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,undef));
		#Checking that the solution exists
		if (!-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingSolutionTable.txt") {
			$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-GFS.txt",["Experiment;Solution index;Solution cost;Solution reactions"]);
			return $self->error_message({function => "datagapfill",message => "Could not find MFA output file!"});
		}
		my $GapFillResultTable = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingSolutionTable.txt",";","",0,undef);
		if (defined($TansferFileSuffix)) {
			system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingSolutionTable.txt ".$self->directory().$self->id().$self->selected_version()."-".$TansferFileSuffix.".txt");
		}
		#If the system is not configured to preserve all logfiles, then the mfatoolkit output folder is deleted
		print $self->config("MFAToolkit output directory")->[0].$UniqueFilename."\n";
		$self->figmodel()->clearing_output($UniqueFilename,"GapFilling-".$self->id().$self->selected_version()."-".$UniqueFilename.".log");
		return $GapFillResultTable;
	}
	if (defined($TansferFileSuffix)) {
		$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-".$TansferFileSuffix.".txt",["Experiment;Solution index;Solution cost;Solution reactions"]);
	}
	return undef;
}

=head3 TestSolutions
Definition:
	$model->TestSolutions($ModelID,$NumProcessors,$ProcessorIndex,$GapFill);
Description:
Example:
=cut

sub TestSolutions {
	my ($self,$OriginalErrorFilename,$GapFillResultTable) = @_;
	#Getting the filename
	my $UniqueFilename = $self->figmodel()->filename();
	#Reading in the original error matrix which has the headings for the original model simulation
	my $OriginalErrorData;
	if (!defined($OriginalErrorFilename) || !-e $self->directory().$OriginalErrorFilename) {
		my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->RunAllStudiesWithDataFast("All");
		$OriginalErrorData = [$HeadingVector,$Errorvector];
	} else {
		$OriginalErrorData = $self->figmodel()->database()->load_single_column_file($self->directory().$OriginalErrorFilename,"");
	}
	my $HeadingHash;
	my @HeadingArray = split(/;/,$OriginalErrorData->[0]);
	my @OrigErrorArray = split(/;/,$OriginalErrorData->[1]);
	for (my $i=0; $i < @HeadingArray; $i++) {
		my @SubArray = split(/:/,$HeadingArray[$i]);
		$HeadingHash->{$SubArray[0].":".$SubArray[1].":".$SubArray[2]} = $i;
	}
	#Scanning through the gap filling solutions
	my $TempVersion = "V".$UniqueFilename;
	my $ErrorMatrixLines;
	for (my $i=0; $i < $GapFillResultTable->size(); $i++) {
		print "Starting problem solving ".$i."\n";
		my $ErrorLine = $GapFillResultTable->get_row($i)->{"Experiment"}->[0].";".$GapFillResultTable->get_row($i)->{"Solution index"}->[0].";".$GapFillResultTable->get_row($i)->{"Solution cost"}->[0].";".$GapFillResultTable->get_row($i)->{"Solution reactions"}->[0];
		#Integrating solution into test model
		my $ReactionArray;
		my $DirectionArray;
		my @ReactionList = split(/,/,$GapFillResultTable->get_row($i)->{"Solution reactions"}->[0]);
		my %SolutionHash;
		for (my $k=0; $k < @ReactionList; $k++) {
			if ($ReactionList[$k] =~ m/(.+)(rxn\d\d\d\d\d)/) {
				my $Reaction = $2;
				my $Sign = $1;
				if (defined($SolutionHash{$Reaction})) {
					$SolutionHash{$Reaction} = "<=>";
				} elsif ($Sign eq "-") {
					$SolutionHash{$Reaction} = "<=";
				} elsif ($Sign eq "+") {
					$SolutionHash{$Reaction} = "=>";
				} else {
					$SolutionHash{$Reaction} = $Sign;
				}
			}
		}
		@ReactionList = keys(%SolutionHash);
		for (my $k=0; $k < @ReactionList; $k++) {
			push(@{$ReactionArray},$ReactionList[$k]);
			push(@{$DirectionArray},$SolutionHash{$ReactionList[$k]});
		}
		print "Integrating solution!\n";
		$self->figmodel()->IntegrateGrowMatchSolution($self->id().$self->selected_version(),$self->directory().$self->id().$TempVersion.".txt",$ReactionArray,$DirectionArray,"Gapfilling ".$GapFillResultTable->get_row($i)->{"Experiment"}->[0],1,1);
		$self->PrintModelLPFile();
		#Running the model against all available experimental data
		print "Running test model!\n";
		my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->RunAllStudiesWithDataFast("All");

		@HeadingArray = split(/;/,$HeadingVector);
		my @ErrorArray = @OrigErrorArray;
		my @TempArray = split(/;/,$Errorvector);
		for (my $j=0; $j < @HeadingArray; $j++) {
			my @SubArray = split(/:/,$HeadingArray[$j]);
			$ErrorArray[$HeadingHash->{$SubArray[0].":".$SubArray[1].":".$SubArray[2]}] = $TempArray[$j];
		}
		$ErrorLine .= ";".$FalsePostives."/".$FalseNegatives.";".join(";",@ErrorArray);
		push(@{$ErrorMatrixLines},$ErrorLine);
		print "Finishing problem solving ".$i."\n";
	}
	#Clearing out the test model
	if (-e $self->directory().$self->id().$TempVersion.".txt") {
		unlink($self->directory().$self->id().$TempVersion.".txt");
		unlink($self->directory()."SimulationOutput".$self->id().$TempVersion.".txt");
	}
	return $ErrorMatrixLines;
}

=head3 generate_fulldb_model
Definition:
	FIGMODELmodel->generate_fulldb_model({
		biomass => string(bio00001)	
	});
Description:
=cut
sub generate_fulldb_model {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	#Clearing the old models
	my $rxnmdl = $self->rxnmdl();
	for (my $i=0; $i < @{$rxnmdl}; $i++) {
		$rxnmdl->[$i]->delete();
	}
	#Setting the biomass reaction if necessary
	if ($self->ppo()->biomassReaction() !~ m/bio\d+/) {
		$self->ppo()->biomassReaction("bio00001");
	}
	#Regenerating all reactions
	my $rxn = $self->db()->get_objects("reaction");
	for (my $i=0; $i < @{$rxn}; $i++) {
		$self->db()->create_object("rxnmdl",{
			MODEL => $self->id(),
			REACTION => $rxn->[$i]->id(),
			directionality => $self->figmodel()->reversibility_of_reaction($rxn->[$i]->id()),
			compartment => "c",
			pegs => "UNKNOWN",
			reference => "NONE",
			notes => "NONE",
			confidence => 5
		});
	}
	$self->db()->create_object("rxnmdl",{
		MODEL => $self->id(),
		REACTION => $self->ppo()->biomassReaction(),
		directionality => "=>",
		compartment => "c",
		pegs => "BIOMASS",
		reference => "NONE",
		notes => "NONE",
		confidence => 5
	});
	$self->set_status(1,"Complete database model reconstruction complete");
	$self->processModel();
	return {success => 1};
}

=head3 preliminary_reconstruction
Definition:
	FIGMODELmodel->preliminary_reconstruction({
		runGapfilling => 1,	
	});
Description:
=cut
sub preliminary_reconstruction {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		runGapfilling => 1
	});
	#If the genome is "Complete", then we build the model for the entire database
	if ($self->genome() =~ m/Complete/) {
		return $self->generate_fulldb_model();
	}
	#Getting genome data and feature table
	my $genomeObj = $self->genomeObj();
	if (!defined($genomeObj)) {
		$self->set_status(-2,"Could not create genome object!");
		return $self->error_message({function => "preliminary_reconstruction",message => "Could not create genome object!"});
	}
	my $ftrTbl = $genomeObj->feature_table();
	if (!defined($ftrTbl)) {
		$self->set_status(-2,"Could not obtain feature table for genome!");
		return $self->error_message({function => "preliminary_reconstruction",message => "Could not obtain feature table!"});
	}
	#Checking that the number of genes exceeds the minimum size
	if ($ftrTbl->size() < $self->config("minimum genome size for modeling")->[0]) {
		$self->set_status(-2,"Genome too small. Model will not be gapfilled!");
	}
	#Checking that a directory exists for the model (should have been created in "new" function)
	my $directory = $self->directory();
	if (!-d $directory) {
		return $self->error_message({function => "preliminary_reconstruction",message => "Model directory does not exist!"});
	}
	#Reseting status so model is built twice at the same time
	if ($self->status() == 0) {
		return $self->error_message({function => "preliminary_reconstruction",message => "model is already being built. Canceling current build."});
	}elsif ($self->status() == 1) {
		$self->set_status(0,"Rebuilding preliminary reconstruction");
	} else {
		$self->set_status(0,"Preliminary reconstruction");
	}
	#Populating datastructures for the GPR generation function from the feature table
	my ($escores,$functional_roles,$mapped_DNA,$locations);
	for (my $i=0; $i < $ftrTbl->size(); $i++) {
		my $row = $ftrTbl->get_row($i);
		my $geneID = $row->{ID}->[0];
		if ($genomeObj->source() eq "MGRAST" && $geneID =~ m/(\d+\.\d+\.peg\.\d+)/) {
			$geneID = $1;
		} elsif ($geneID =~ m/(peg\.\d+)/) {
			$geneID = $1;
		}
		if (defined($row->{ROLES}->[0])) {
			for (my $j=0; $j < @{$row->{ROLES}}; $j++) {
				push(@{$functional_roles},$row->{ROLES}->[$j]);
				push(@{$mapped_DNA},$geneID);
				if (defined($row->{"MIN LOCATION"}->[0]) && defined($row->{"MAX LOCATION"}->[0])) {
					my $average = ($row->{"MIN LOCATION"}->[0]+$row->{"MAX LOCATION"}->[0])/2;
					push(@{$locations},$average);
				} elsif (defined($row->{"MIN LOCATION"}->[0])) {
					push(@{$locations},$row->{"MIN LOCATION"}->[0]);
				} elsif (defined($row->{"MAX LOCATION"}->[0])) {
					push(@{$locations},$row->{"MAX LOCATION"}->[0]);
				} else {
					push(@{$locations},-1);
				}
			}
		}
		if (defined($row->{EVALUE})) {
			$escores->{$geneID} = $row->{EVALUE};
		}
	}
	my $ReactionHash = $self->generate_model_gpr({
		roles => $functional_roles,
		genes => $mapped_DNA,
		locations => $locations
	});
	if (!defined($ReactionHash)) {
		return $self->error_message({function => "preliminary_reconstruction",message => "Could not generate reaction GPR!"});
	}
	#Creating the model reaction table
	my $newRxnRowHash;
	foreach my $rxn (keys(%{$ReactionHash})) {
		my $reference = $genomeObj->source();
		if (defined($escores->{$rxn})) {
			$reference = join("|",@{$escores->{$rxn}});
		}
		$newRxnRowHash->{$rxn} = {
			MODEL => $self->id(),
			REACTION => $rxn,
			directionality => $self->figmodel()->reversibility_of_reaction($rxn),
			compartment => "c",
			pegs => join("|",@{$ReactionHash->{$rxn}}),
			reference => $reference,
			notes => "NONE",
			confidence => 3
		};
	}
	#Adding the spontaneous and universal reactions
	foreach my $rxn (@{$self->config("spontaneous reactions")}) {
		if (!defined($newRxnRowHash->{$rxn})) {
			$newRxnRowHash->{$rxn} = {
				MODEL => $self->id(),
				REACTION => $rxn,
				directionality => $self->figmodel()->reversibility_of_reaction($rxn),
				compartment => "c",
				pegs => "SPONTANEOUS",
				reference => "NONE",
				notes => "NONE",
				confidence => 4
			};
		}
	}
	foreach my $rxn (@{$self->config("universal reactions")}) {
		if (!defined($newRxnRowHash->{$rxn})) {
			$newRxnRowHash->{$rxn} = {
				MODEL => $self->id(),
				REACTION => $rxn,
				directionality => $self->figmodel()->reversibility_of_reaction($rxn),
				compartment => "c",
				pegs => "UNIVERSAL",
				reference => "NONE",
				notes => "NONE",
				confidence => 4
			};
		}
	}
	#Completing any incomplete reactions sets
	if (defined($self->figmodel()->config("reaction sets"))) {
		foreach my $rxn (keys(%{$self->figmodel()->config("reaction sets")})) {
			if (defined($newRxnRowHash->{$rxn})) {
				my $set = [split(/,/,$self->figmodel()->config("reaction sets")->{$rxn}->[0])];
				foreach my $Reaction (@{$set}) {
					if (!defined($newRxnRowHash->{$Reaction})) {
						$newRxnRowHash->{$Reaction} = {
							MODEL => $self->id(),
							REACTION => $Reaction,
							directionality => $self->figmodel()->reversibility_of_reaction($Reaction),
							compartment => "c",
							pegs => "UNIVERSAL",
							reference => "NONE",
							notes => "NONE",
							confidence => 4
						};
					}
				}
			}
		}
	}
	#Creating biomass reaction for model
	my $biomassID;
	if ($genomeObj->source() eq "MGRAST") {
		$biomassID = "bio00001";
	} else {
		$biomassID = $self->BuildSpecificBiomassReaction();
		if ($biomassID !~ m/bio\d\d\d\d\d/) {
			$self->set_status(-2,"Preliminary reconstruction failed: could not generate biomass reaction");
			return $self->error_message({function => "CreateMetabolicModel",message => "Could not generate biomass reaction!"});
		}
	}
	#Getting the biomass reaction PPO object
	my $bioRxn = $self->figmodel()->database()->get_object("bof",{id=>$biomassID});
	if (!defined($bioRxn)) {
		 $self->set_status(-2,"Preliminary reconstruction failed: could not find biomass reaction ".$biomassID);
		return $self->error_message({function => "CreateMetabolicModel",message => "Could not find biomass reaction ".$biomassID});
	}
	#Getting the list of essential reactions for biomass reaction
	my $ReactionList;
	my $essentialReactions = $bioRxn->essentialRxn();
	if (defined($essentialReactions) && $essentialReactions =~ m/rxn\d\d\d\d\d/) {
		push(@{$ReactionList},split(/\|/,$essentialReactions));
		if ($essentialReactions !~ m/$biomassID/) {
			push(@{$ReactionList},$biomassID);
		}
	} else {
		push(@{$ReactionList},$biomassID);
	}
	#Adding biomass reactions to the model table
	foreach my $BOFReaction (@{$ReactionList}) {
		if (!defined($newRxnRowHash->{$BOFReaction})) {
			my ($direction,$pegs,$confidence);
			if ($BOFReaction =~ m/bio/) {
				$direction = "=>";
				$pegs = "BIOMASS";
				$confidence = 1;
			} else {
				$direction = $self->figmodel()->reversibility_of_reaction($BOFReaction);
				$pegs = "BIOMASS AUTOCOMPLETION";
				$confidence = 5;
			}
			$newRxnRowHash->{$BOFReaction} = {
				MODEL => $self->id(),
				REACTION => $BOFReaction,
				directionality => $direction,
				compartment => "c",
				pegs => "UNIVERSAL",
				reference => "SEED",
				notes => "NONE",
				confidence => $confidence
			};
		}
	}
   	#If a model already exists, we checkpoint
	my $rxnMdl = $self->rxnmdl({clearCache => 1});
	my $checkpointed = 0;
	if (@{$rxnMdl} == 0) {
		$checkpointed = 1;	
	}
	my $changed = 0;
	my $compareHeadings = ["directionality","compartment","pegs"];
	for (my $i=0; $i < @{$rxnMdl}; $i++) {
		#Checking if the reaction is present in the new model formulation
		if (defined($newRxnRowHash->{$rxnMdl->[$i]->REACTION()})) {
			$newRxnRowHash->{$rxnMdl->[$i]->REACTION()}->{found} = 1;
			foreach my $heading (@{$compareHeadings}) {
				if ($rxnMdl->[$i]->$heading() ne $newRxnRowHash->{$rxnMdl->[$i]->REACTION()}->{$heading}) {
					if ($checkpointed == 0) {
						$checkpointed = 1;
						$self->checkpoint();
					}
					$rxnMdl->[$i]->$heading($newRxnRowHash->{$rxnMdl->[$i]->REACTION()}->{$heading});
					$changed = 1;	
				}
			}
			if ($changed == 1 && $rxnMdl->[$i]->confidence() > $newRxnRowHash->{$rxnMdl->[$i]->REACTION()}->{confidence}) {
				$rxnMdl->[$i]->confidence($newRxnRowHash->{$rxnMdl->[$i]->REACTION()}->{confidence});	
			}
		#Reaction is not in new model formulation and should be deleted
		} elsif ($rxnMdl->[$i]->pegs() !~ m/AUTOCOMPLETION/) {#Keeping previous autocompletion results
			if ($checkpointed == 0) {
				$checkpointed = 1;
				$self->checkpoint();
			}
			$rxnMdl->[$i]->delete();
			$changed = 1;
		}
	}
	foreach my $rxn (keys(%{$newRxnRowHash})) {
		if (!defined($newRxnRowHash->{$rxn}->{found})) {
			if ($checkpointed == 0) {
				$checkpointed = 1;
				$self->checkpoint();
			}
			$changed = 1;
			$self->figmodel()->database()->create_object("rxnmdl",$newRxnRowHash->{$rxn});	
		}
	}
	if ($changed == 0) {
		$self->set_status(1,"Rebuild canceled because model has not changed");
		return {success => 1};
	}
	$self->set_status(1,"Preliminary reconstruction complete");
	#Canceling gapfilling if number of reactions is too small
	$rxnMdl = $self->rxnmdl({clearCache => 1});
	if (@{$rxnMdl} < 100) {
		$args->{runGapfilling} = 0;
		$self->set_status(1,"Reconstruction complete. Genome too small for gapfilling.");
	}
	#Adding model to gapfilling queue
	if ($args->{runGapfilling} == 1) {
		$self->set_status(1,"Autocompletion queued");
		$self->figmodel()->add_job_to_queue({command => "gapfillmodel?".$self->id(),user => $self->owner(),queue => "cplex"});
	}
	$self->processModel();
	return {success => 1};
}

=head3 generate_model_gpr
Definition:
	{string:reaction id => [string]:complexes} = FIGMODELmodel->generate_model_gpr([string]:functional roles,[string]:mapped DNA,[double]:locations);
=cut

sub generate_model_gpr {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["roles","genes"],{
		locations => undef,
	});
	return $self->error_message({function => "generate_model_gpr",args=>$args}) if (defined($args->{error}));
   	#Creating a hash of gene locations
   	my $locations;
	if (defined($args->{locations})) {
		for (my $i=0; $i < @{$args->{genes}}; $i++) {
			$locations->{$args->{genes}->[$i]} = $args->{locations}->[$i];
		}
	}
	#Converting the functional roles to IDs
	my $roleHash;
	for (my $i=0; $i < @{$args->{roles}}; $i++) {
		my $roles = $self->figmodel()->get_role()->roles_of_function({
			function => $args->{roles}->[$i],
			output => "id"
		});		
		for (my $j=0; $j < @{$roles}; $j++) {
			$roleHash->{$roles->[$j]}->{$args->{genes}->[$i]} = 1;
		}
	}
	#Getting the entire list of complexes mapped to reaction and saving mapping into a hash
	my $complexHash;
	my $rxncpxs = $self->figmodel()->database()->get_objects("rxncpx");
	for (my $i=0; $i < @{$rxncpxs}; $i++) {
		if ($rxncpxs->[$i]->master() == 1) {
			push(@{$complexHash->{$rxncpxs->[$i]->COMPLEX()}},$rxncpxs->[$i]->REACTION());
		}
	}
	#Getting the functional roles associated with each complex
	my $modelComplexes;
	my $cpxroles = $self->figmodel()->database()->get_objects("cpxrole");
	for (my $i=0; $i < @{$cpxroles}; $i++) {
		if (defined($complexHash->{$cpxroles->[$i]->COMPLEX()})) {
			if ($cpxroles->[$i]->type() ne "N") {
				if (defined($roleHash->{$cpxroles->[$i]->ROLE()})) {
					push(@{$modelComplexes->{$cpxroles->[$i]->COMPLEX()}->{$cpxroles->[$i]->type()}->{$cpxroles->[$i]->ROLE()}},keys(%{$roleHash->{$cpxroles->[$i]->ROLE()}}));
				}
			}
		}
	}
	#Forming the GPR for each complex
	my $complexGPR;
	my @complexes = keys(%{$modelComplexes});
	for (my $i=0; $i < @complexes; $i++) {
		if (defined($modelComplexes->{$complexes[$i]}->{"G"})) {
			my @roles = keys(%{$modelComplexes->{$complexes[$i]}->{"G"}});
			#Counting the number of possible combinations to determine if we should bother with complexes
			my $totalComplexes = 1;
			for (my $j=0; $j < @roles; $j++) {
				$totalComplexes = $totalComplexes*@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}};
			}
			#If the number of possible complexes is too large, we just add all genes as "or" associations
			if ($totalComplexes > 20 || !defined($locations)) {
				for (my $j=0; $j < @roles; $j++) {
					push(@{$complexGPR->{$complexes[$i]}},@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}});
				}
			} else {
				#Identifying colocalized pairs of roles and combining their GPR
				for (my $j=0; $j < @roles; $j++) {
					for (my $k=$j+1; $k < @roles; $k++) {
						my $colocalized = 0;
						my $newGPR;
						my $foundHash;
						for (my $m=0; $m < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}}; $m++) {
							my @genes = split(/\+/,$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$m]);
							my $found = 0;
							for (my $n=0; $n < @genes; $n++) {
								for (my $o=0; $o < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}}; $o++) {
									if (abs($locations->{$genes[$n]}-$locations->{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]}) < 5000) {
										push(@{$newGPR},$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$m]."+".$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]);
										$foundHash->{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]} = 1;
										$found = 1;
										last;
									}
								}
								if ($found == 1) {
									last;	
								}
							}
							if ($found == 1) {
								$colocalized++;
							} else {
								push(@{$newGPR},$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$m]);
							}
						}
						#If over half the genes associated with both roles are colocalized, we combine the roles into a single set of GPR
						if ($colocalized/@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}} > 0.5 && $colocalized/@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}} > 0.5) {
							#Adding any noncolocalized genes found in the second role
							for (my $o=0; $o < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}}; $o++) {
								if (!defined($foundHash->{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]})) {
									push(@{$newGPR},$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]);
								}
							}
							#Replacing the old GPR for the first role with the new combined GPR
							$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]} = $newGPR;
							#Deleting the second role
							splice(@roles,$k,1);
							$k--;
						}
					}
				}
				#Combinatorially creating all remaining complexes
				push(@{$complexGPR->{$complexes[$i]}},@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[0]}});
				for (my $j=1; $j < @roles; $j++) {
					my $newMappings;
					for (my $m=0; $m < @{$complexGPR->{$complexes[$i]}}; $m++) {
						for (my $k=0; $k < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}}; $k++) {
							push(@{$newMappings},$complexGPR->{$complexes[$i]}->[$m]."+".$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$k]);
						}
					}
					$complexGPR->{$complexes[$i]} = $newMappings;
				}
			}
			#Adding global generic complex elements
			if (defined($modelComplexes->{$complexes[$i]}->{"L"})) {
				my $totalComplexes = @{$complexGPR->{$complexes[$i]}};
				@roles = keys(%{$modelComplexes->{$complexes[$i]}->{"L"}});
				for (my $j=0; $j < @roles; $j++) {
					$totalComplexes = $totalComplexes*@{$modelComplexes->{$complexes[$i]}->{"L"}->{$roles[$j]}};
				}
				if ($totalComplexes < 20) {
					for (my $j=0; $j < @roles; $j++) {
						my $newGeneAssociations;
						for (my $k=0; $k < @{$modelComplexes->{$complexes[$i]}->{"L"}->{$roles[$j]}}; $k++) {
							if (defined($complexGPR->{$complexes[$i]})) {
								for (my $m=0; $m < @{$complexGPR->{$complexes[$i]}}; $m++) {
									my $peg = $modelComplexes->{$complexes[$i]}->{"L"}->{$roles[$j]}->[$k];
									if ($complexGPR->{$complexes[$i]}->[$m] !~ m/$peg/) {
										push(@{$newGeneAssociations},$complexGPR->{$complexes[$i]}->[$m]."+".$peg);
									} else {
										push(@{$newGeneAssociations},$complexGPR->{$complexes[$i]}->[$m]);
									}
								}
							}
						}
						$complexGPR->{$complexes[$i]} = $newGeneAssociations;
					}
				}
			}
		}
	}
	#Translating the complex GPR into a reaction gpr
	my $reactionGPR;
	@complexes = keys(%{$complexGPR});
	for (my $i=0; $i < @complexes; $i++) {
		for (my $j=0; $j < @{$complexHash->{$complexes[$i]}}; $j++) {
			if (defined($complexGPR->{$complexes[$i]}->[0])) {
				push(@{$reactionGPR->{$complexHash->{$complexes[$i]}->[$j]}},@{$complexGPR->{$complexes[$i]}});
			}
		}
	}
	#Looking for colocalized gene associations we can combine into additional complexes
	if (defined($locations)) {
		my @reactions = keys(%{$reactionGPR});
		for (my $i=0; $i < @reactions; $i++) {
			for (my $j=0; $j < @{$reactionGPR->{$reactions[$i]}}; $j++) {
				if (defined($reactionGPR->{$reactions[$i]}->[$j])) {
					my @geneList = split(/\+/,$reactionGPR->{$reactions[$i]}->[$j]);
					for (my $k=$j+1; $k < @{$reactionGPR->{$reactions[$i]}}; $k++) {
						if (defined($reactionGPR->{$reactions[$i]}->[$k])) {
							my @otherGeneList = split(/\+/,$reactionGPR->{$reactions[$i]}->[$k]);
							my $combine = 0;
							for (my $n=0; $n < @geneList; $n++) {
								my $neighbor = 0;
								my $match = 0;
								for (my $m=0; $m < @otherGeneList; $m++) {
									if ($geneList[$n] eq $otherGeneList[$m]) {
										$match = 1;
										last;
									} elsif (abs($locations->{$geneList[$n]}-$locations->{$otherGeneList[$m]}) < 5000) {
										$neighbor = 1;	
									}
								}
								if ($neighbor == 1 && $match == 0) {
									$combine = 1;
									last;
								}
							}
							#If a neighbor is found in the second set, we combine the sets
							if ($combine == 1) {
								my $geneHash;
								for (my $n=0; $n < @geneList; $n++) {
									$geneHash->{$geneList[$n]} = 1;
								}
								for (my $n=0; $n < @otherGeneList; $n++) {
									$geneHash->{$otherGeneList[$n]} = 1;
								}
								$reactionGPR->{$reactions[$i]}->[$j] = join("+",sort(keys(%{$geneHash})));
								@geneList = keys(%{$geneHash});
								splice(@{$reactionGPR->{$reactions[$i]}},$k,1);
								$k--;
							}
						}
					}
				}
			}
		}
	}
	#Ensuring that genes in complexes are sorted and never repeated
	my @reactions = keys(%{$reactionGPR});
	for (my $i=0; $i < @reactions; $i++) {
		for (my $j=0; $j < @{$reactionGPR->{$reactions[$i]}}; $j++) {
			my @genes = split(/\+/,$reactionGPR->{$reactions[$i]}->[$j]);
			my $genehash;
			for (my $k=0; $k < @genes; $k++) {
				$genehash->{$genes[$k]} =1;
			}
			$reactionGPR->{$reactions[$i]}->[$j] = join("+",sort(keys(%{$genehash})));
		}
		#Ensuring that the complexes are sorted as well, to make a canonical ordering
		$reactionGPR->{$reactions[$i]} = [sort(@{$reactionGPR->{$reactions[$i]}})];
	}
	#Returning the result
	return $reactionGPR;
}

=head3 ArchiveModel
Definition:
	(success/fail) = FIGMODELmodel->ArchiveModel();
Description:
	This function archives the specified model in the model directory with the current version numbers appended.
	This function is used to preserve old versions of models prior to overwriting so new versions may be compared with old versions.
=cut
sub ArchiveModel {
	my ($self) = @_;

	#Checking that the model file exists
	if (!(-e $self->filename())) {
		return $self->error_message({function => "ArchiveModel",message => "Model file ".$self->filename()." not found!"});
	}

	#Copying the model file
	system("cp ".$self->filename()." ".$self->directory().$self->id().$self->version().".txt");
}
=head3 printModelFileForMFAToolkit
Definition:
	{} = FIGMODELmodel->printModelFileForMFAToolkit({
		filename => $self->directory().$self->id().".tbl"
	});
Description:
	Prints the model reaction table to the input filename.
=cut
sub printModelFileForMFAToolkit {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		removeGapfilling => 0,
		filename => $self->directory().$self->id().".tbl"
	});
	return $self->error_message({function => "printModelFileForMFAToolkit",args => $args}) if (defined($args->{error}));
	my $output = ["REACTIONS","LOAD;DIRECTIONALITY;COMPARTMENT;ASSOCIATED PEG;SUBSYSTEM;CONFIDENCE;REFERENCE;NOTES"];
	my $objs = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL=>$self->id()});
	for (my $i=0; $i < @{$objs}; $i++) {
		if ($args->{removeGapfilling} == 0 || ($objs->[$i]->pegs() !~ m/GAP/ && $objs->[$i]->pegs() !~ m/AUTO/)) {
			my $line = $objs->[$i]->REACTION().";".$objs->[$i]->directionality().";".$objs->[$i]->compartment().";"
				.$objs->[$i]->pegs().";NONE;".$objs->[$i]->confidence().";NONE;NONE";
			push(@{$output},$line);
		}
	}
	$self->figmodel()->database()->print_array_to_file($args->{filename},$output);
	return {success=>1};
}

=head3 PrintModelDataToFile
Definition:
	(success/fail) = FIGMODELmodel->PrintModelDataToFile();
Description:
	This function uses the MFAToolkit to print out all of the compound and reaction data for the input model.
	Some of the data printed by the toolkit is calculated internally in the toolkit and not stored in any files, so this data can only be retrieved through this
	function. The LoadModel function for example would not give you this data.
=cut
sub PrintModelDataToFile {
	my($self) = @_;

	#Running the MFAToolkit on the model file
	my $OutputIndex = $self->figmodel()->filename();
	my $Command = $self->config("MFAToolkit executable")->[0]." parameterfile ../Parameters/Printing.txt resetparameter output_folder ".$OutputIndex.'/ LoadCentralSystem "'.$self->filename().'"';
	system($Command);

	#Copying the model file printed by the toolkit out of the output directory and into the model directory
	if (!-e $self->config("MFAToolkit output directory")->[0].$OutputIndex."/".$self->id().$self->selected_version().".txt") {
		return $self->error_message({function => "PrintModelDataToFile",message => "New model file not created due to an error. Check that the input modelfile exists."});
	}

	$Command = 'cp "'.$self->config("MFAToolkit output directory")->[0].$OutputIndex."/".$self->id().$self->selected_version().'.txt" "'.$self->directory().$self->id().$self->selected_version().'Data.txt"';
	system($Command);
	$Command = 'cp "'.$self->config("MFAToolkit output directory")->[0].$OutputIndex.'/ErrorLog0.txt" "'.$self->directory().'ModelErrors.txt"';
	system($Command);
	$self->figmodel()->cleardirectory($OutputIndex);
	return $self->figmodel()->success();
}

sub GenerateModelProvenance {
	my ($self, $args) = @_;
	$args = $self->figmodel()->process_arguments($args,[], {
		biochemSource => undef,
		mappingSource => undef,
		annotationSource => undef,
		targetDirectory => $self->directory(),
		clearCurrentProvenance => 1
	});
	# Current directory structure:
	# biochemistry/
	#	 reaction.txt
	#	 compound.txt
	#	 rxnals.txt
	#	 cpdals.txt
	# mappings/
	#	 rxncpx.txt
	#	 complex.txt
	#	 cpxrole.txt
	# annotations/
	#	 features.txt
	# Doing biochemistry
	my $model_directory = $args->{targetDirectory}; 
	if(!-d $model_directory) {
		File::Path::mkpath $model_directory;
	}
	my $db = $self->figmodel()->database();
	{
		my $biochemd = $model_directory."biochemistry/";
		if(!-d $biochemd) {
			mkdir $biochemd;
		}
		if ($args->{clearCurrentProvenance} == 1) {
			unlink $biochemd.'reaction.txt';
			unlink $biochemd.'rxnals.txt';
			unlink $biochemd.'compound.txt';
			unlink $biochemd.'cpdals.txt';
		}
		if (defined($args->{biochemSource}) && -d $args->{biochemSource}) {
			system("cp ".$args->{biochemSource}."* ".$biochemd);
		}
		if (!-e $biochemd.'reaction.txt') {
			my $rxn_config = {
				filename => $biochemd.'reaction.txt',
				hash_headings => ['id', 'code'],
				delimiter => "\t",
				item_delimiter => "|",
			};
			my $rxntbl = $db->ppo_rows_to_table($rxn_config, 
				$db->get_objects('reaction', {}));
			$rxntbl->save();
		}
		if (!-e $biochemd.'rxnals.txt') {
			my $rxnals_config = {
				filename => $biochemd.'rxnals.txt',
				hash_headings => ['REACTION', 'type', 'alias'],
				delimiter => "\t",
				item_delimiter => "|",
			};
			my $rxn_als_tbl = $db->ppo_rows_to_table($rxnals_config, 
				$db->get_objects('rxnals', {}));
			$rxn_als_tbl->save();
		}
		if (!-e $biochemd.'compound.txt') {
			my $cpd_config = {
				filename => $biochemd.'compound.txt',
				hash_headings => ['id', 'name', 'formula'],
				delimiter => "\t",
				item_delimiter => ";",
			};
			my $cpdtbl = $db->ppo_rows_to_table($cpd_config,
				$db->get_objects('compound', {}));
			$cpdtbl->save();
		}
		if (!-e $biochemd.'cpdals.txt') {
			my $cpdals_config = {
				filename => $biochemd.'cpdals.txt',
				hash_headings => ['COMPOUND', 'type', 'alias'],
				delimiter => "\t",
				item_delimiter => "|",
			};
			my $cpd_als_tbl = $db->ppo_rows_to_table($cpdals_config,
				$db->get_objects('cpdals', {}));
			$cpd_als_tbl->save();
		}
	}
	# Doing mappings
	{
		my $mappingd = $model_directory."mapping/";
		if(!-d $mappingd) {
			mkdir $mappingd;
		}
		if ($args->{clearCurrentProvenance} == 1) {
			unlink $mappingd.'complex.txt';
			unlink $mappingd.'rxncpx.txt';
			unlink $mappingd.'cpxrole.txt';
			unlink $mappingd.'role.txt';
		}
		if (defined($args->{mappingSource}) && -d $args->{mappingSource}) {
			system("cp ".$args->{mappingSource}."* ".$mappingd);
		}
		if (!-e $mappingd.'complex.txt') {
			my $complex_config = {
				filename => $mappingd.'complex.txt',
				hash_headings => ['id'],
				delimiter => "\t",
				item_delimiter => ";",
			};
			my $cpxtbl = $db->ppo_rows_to_table($complex_config,
				$db->get_objects('complex', {}));
			$cpxtbl->save();
		}
		if (!-e $mappingd.'rxncpx.txt') {
			my $rxncpx_config = {
				filename => $mappingd.'rxncpx.txt',
				hash_headings => ['REACTION', 'COMPLEX', 'type'],
				delimiter => "\t",
				item_delimiter => ";",
			};
			my $rxncpxtbl = $db->ppo_rows_to_table($rxncpx_config,
				$db->get_objects('rxncpx', {}));
			$rxncpxtbl->save();
		}
		if (!-e $mappingd.'cpxrole.txt') {
			my $cpxrole_config = {
				filename => $mappingd.'cpxrole.txt',
				hash_headings => ['ROLE', 'COMPLEX', 'type'],
				delimiter => "\t",
				item_delimiter => ";",
			};
			my $cpxroletbl = $db->ppo_rows_to_table($cpxrole_config,
				$db->get_objects('cpxrole', {}));
			$cpxroletbl->save();
		}
		if (!-e $mappingd.'role.txt') {
			my $role_config = {
				filename => $mappingd.'role.txt',
				hash_headings => ['id', 'name', 'searchname'],
				delimiter => "\t",
				item_delimiter => ";",
			};
			my $roletbl = $db->ppo_rows_to_table($role_config,
				$db->get_objects('role', {}));
			$roletbl->save();
		}
	}
	# Doing annotations
	{
		if (lc($self->genome()) ne "unknown" && lc($self->genome()) ne "none" && defined($self->genomeObj())) {
			my $annod = $model_directory."annotations/";
			if(!-d $annod) {
				mkdir $annod;
			}
			if ($args->{clearCurrentProvenance} == 1) {
				unlink $annod.'features.txt';
			}
			if (defined($args->{annotationSource}) && -d $args->{annotationSource}) {
				system("cp ".$args->{annotationSource}."* ".$annod);
			}
			if (!-e $annod.'features.txt') {
				my $feature_table = $self->genomeObj()->feature_table();
				$feature_table->save($annod.'features.txt');
			}
		}
	}
	return $self->figmodel()->success() 

}
=head3 InspectModelState
Definition:
	undef = FIGMODELmodel->InspectModelState();
Description:
=cut
sub InspectModelState {
	my ($self, $args) = @_;
	$args = $self->figmodel()->process_arguments($args,[], {});
	#Clearing previous global messages
	my $msgs = $self->db()->get_objects("message",{
		id => $self->id(),
		function => "InspectModelState"
	});
	for (my $i=0; $i < @{$msgs}; $i++) {
		$msgs->[$i]->delete();
	}
	#Loading model from old system
	my $tbl = $self->figmodel()->database()->load_table(
		"/vol/model-dev/MODEL_DEV_DB/Models/".$self->owner()."/".$self->genome()."/".$self->id().".txt",
		";",
		"|",
		1,
		["LOAD","COMPARTMENT"]
	);
	#Checking that the model is properly loaded into PPO
	my $rxnmdl = $self->rxnmdl();
	my $rxnMdlHash;
	for (my $i=0; $i < @{$rxnmdl}; $i++) {
		my $obj = $tbl->get_object({"LOAD"=>$rxnmdl->[$i]->REACTION(),"COMPARTMENT"=>$rxnmdl->[$i]->compartment()});
		if (!defined($obj) && $rxnmdl->[$i]->pegs() =~ m/peg\./) {
			$self->globalMessage({thread => "warning",msg => $rxnmdl->[$i]->REACTION()." not found in original model!"});
		}
		$rxnMdlHash->{$rxnmdl->[$i]->REACTION()}->{$rxnmdl->[$i]->compartment()} = $rxnmdl->[$i];
	}
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		if (!defined($rxnMdlHash->{$row->{LOAD}->[0]}) || !defined($rxnMdlHash->{$row->{LOAD}->[0]}->{$row->{COMPARTMENT}->[0]})) {
			if (@{$rxnmdl} == 0 || (defined($row->{"ASSOCIATED PEG"}->[0]) && $row->{"ASSOCIATED PEG"}->[0] =~ m/peg\./)) {
				my $pegs = "UNKNOWN";
				if (defined($row->{"ASSOCIATED PEG"}->[0])) {
					$pegs = join("|",@{$row->{"ASSOCIATED PEG"}});
				}
				$self->figmodel()->database()->create_object("rxnmdl",{
					MODEL => $self->id(),
					REACTION => $row->{LOAD}->[0],
					directionality => $row->{DIRECTIONALITY}->[0],
					compartment => $row->{COMPARTMENT}->[0],
					pegs => $pegs,
					confidence => $row->{CONFIDENCE}->[0],
					notes => $row->{NOTES}->[0],
					reference => $row->{REFERENCE}->[0]
				});
			} else {
				$self->globalMessage({thread => "warning",msg => $row->{LOAD}->[0]." not found in ppo!"});
			}
		}
	}
	#Making sure all reactions in model are listed in provenance DB
	$rxnmdl = $self->rxnmdl({clearCache => 1});
	my $rxnHash = $self->figmodel()->database()->get_object_hash({
		type => "reaction",
		attribute => "id",
		useCache => 0,
	});
	for (my $i=0; $i < @{$rxnmdl}; $i++) {
		if ($rxnmdl->[$i]->REACTION() =~ m/rxn\d+/ && !defined($rxnHash->{$rxnmdl->[$i]->REACTION()})) {
			my $rxndata = $self->figmodel()->get_reaction()->file({
				clear => 1,
				filename=> $self->figmodel()->config("reaction directory")->[0].$rxnmdl->[$i]->REACTION()
			});
			if (!defined($rxndata)|| !defined($rxndata->{EQUATION}->[0])) {
				$self->globalMessage({thread => "warning",msg => $rxnmdl->[$i]->REACTION().": data failed to load for this reaction in model!"});
			} else {
				my $rxnhash = {
					id => $rxnmdl->[$i]->REACTION(),
					name => $rxnmdl->[$i]->REACTION(),
					abbrev => $rxnmdl->[$i]->REACTION(),
					reversibility => "<=>",
					thermoReversibility => "<=>",
					owner => $self->owner(),
					scope => $self->id(),
					modificationDate => time(),
					creationDate => time(),
					public => 1
				};
				my $codeResults = $self->figmodel()->get_reaction()->createReactionCode({equation => $rxndata->{"EQUATION"}->[0]});
				if (defined($codeResults->{error}) || !defined($codeResults->{code})) {
					$self->globalMessage({thread => "warning",msg => $rxnmdl->[$i]->REACTION()." code not generated!"});
				} else {
					$rxnhash->{code} = $codeResults->{code};
					my $obj = $self->db()->get_object("reaction",{code => $codeResults->{code}});
					if (defined($obj)) {
						$rxnmdl->[$i]->REACTION($obj->id());
						$self->globalMessage({thread => "warning",msg => $rxnmdl->[$i]->REACTION()." replaced by ".$obj->id()});
					} else {
						my $translations = {
							DATABASE => "id",
							NAME => "name",
							DEFINITION => "definition",
							EQUATION => "equation",
							DELTAG => "deltaG",
							DELTAGERR => "deltaGErr",
							"THERMODYNAMIC REVERSIBILITY" => "thermoReversibility",
							STATUS => "status",
							TRANSATOMS => "transportedAtoms"
						};#Translating MFAToolkit file headings into PPO headings
						foreach my $key (keys(%{$translations})) {#Loading file data into the PPO
							if (defined($rxndata->{$key}->[0])) {
								$rxnhash->{$translations->{$key}} = $rxndata->{$key}->[0];
							}
						}
						if (defined($rxndata->{"STRUCTURAL_CUES"}->[0])) {
							$rxnhash->{structuralCues} = join("|",@{$rxndata->{"STRUCTURAL_CUES"}});	
						}
						$self->globalMessage({thread => "warning",msg => $rxnmdl->[$i]->REACTION()." added to PPO!"});
						my $rxn = $self->figmodel()->database()->create_object("reaction",$rxnhash);
						$self->globalMessage({thread => "masterdb",msg => 
							$self->id()."!".$rxnmdl->[$i]->REACTION()."!".$rxn->name()
							."!".$rxn->abbrev()."!".$rxn->enzyme()."!".$rxn->code()
							."!".$rxn->equation()."!".$rxn->definition()."!".$rxn->deltaG()
							."!".$rxn->deltaGErr()."!".$rxn->structuralCues()."!".$rxn->reversibility()
							."!".$rxn->thermoReversibility()
						});
					}
				}
			}
		} elsif (defined($rxnHash->{$rxnmdl->[$i]->REACTION()})) {
			my $rxn = $rxnHash->{$rxnmdl->[$i]->REACTION()}->[0];
			$self->globalMessage({thread => "masterdb",msg => 
				$self->id()."!".$rxnmdl->[$i]->REACTION()."!".$rxn->name()
				."!".$rxn->abbrev()."!".$rxn->enzyme()."!".$rxn->code()
				."!".$rxn->equation()."!".$rxn->definition()."!".$rxn->deltaG()
				."!".$rxn->deltaGErr()."!".$rxn->structuralCues()."!".$rxn->reversibility()
				."!".$rxn->thermoReversibility()
			});	
		}
	}
}
=head3 add_reaction
Definition:
	{} = FIGMODEL->add_reaction({
		ids => [string],
		directionalitys => [string],
		compartments => [string],
		pegs => [string],
		subsystems => [string],
		confidences => [string],
		references => [string],
		notes => [string],
		reason => "NONE",
		user => $self->figmodel()->user(),
		adjustmentOnly => 1,
	})
Description:
	Adds a reaction to the model and updates model statistics
=cut
sub add_reactions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["ids"],{
		directionalitys => [],
		compartments => [],
		pegs => [[]],
		subsystems => [[]],
		confidences => [],
		references => [[]],
		notes => [[]],
		reason => "NONE",
		user => $self->figmodel()->user(),
		adjustmentOnly => 1,
	});	
	if (defined($args->{error})) {return $self->error_message({function => "add_reactions",args => $args});}
	$self->aquireModelLock();
	my $rxnTable = $self->reaction_table(1);
	for (my $i=0; $i < @{$args->{ids}}; $i++) {
		my $id = $args->{ids}->[$i];
		my $sign = $self->figmodel()->reversibility_of_reaction($id);
		if ($args->{ids}->[$i] =~ m/(.)(rxn\d+)/) {
			$id = $2;
			$sign = $1;
			if ($sign eq "-") {
				$sign = "<=";
			} elsif ($sign eq "+") {
				$sign = "=>";	
			}
		}
		if (defined($args->{directionality}->[$i])) {
			$sign = $args->{directionality}->[$i];
		}
		if (!defined($args->{compartment}->[$i])) {
			$args->{compartment}->[$i] = "c";
		}
		my $row;
		my @rows = $rxnTable->get_rows_by_key($id, 'LOAD');
		for (my $j=0; $j < @rows; $j++) {
			if ($rows[$j]->{COMPARTMENT}->[0] eq $args->{compartment}->[$i]) {
				$row = $rows[$j];
				last;
			}
		}
		my $action = "added";
		if (defined($row) && $args->{adjustmentOnly} == 1) {
			if ($row->{DIRECTIONALITY}->[0] ne $sign) {
				$row->{DIRECTIONALITY}->[0] = "<=>";
			}
			if (defined($args->{subsystem}->[$i]->[0]) && $args->{subsystem}->[$i]->[0] ne "NONE") {
				$rxnTable->add_data($row,"SUBSYSTEM",$args->{subsystems}->[$i],1);
			}
			if (defined($args->{note}->[$i]->[0]) && $args->{note}->[$i]->[0] ne "NONE") {
				$rxnTable->add_data($row,"NOTES",$args->{note}->[$i],1);
			}
			if (defined($args->{reason}) && $args->{reason} ne "NONE") {
				$rxnTable->add_data($row,"NOTES",$args->{reason},1);
			}
			if (defined($args->{reference}->[$i]->[0]) && $args->{reference}->[$i]->[0] ne "NONE") {
				$rxnTable->add_data($row,"REFERENCE",$args->{reference}->[$i],1);
			}
			if (defined($args->{pegs}->[$i]->[0]) && $args->{pegs}->[$i]->[0] ne "UNKNOWN" && $args->{pegs}->[$i]->[0] ne "AUTOCOMPLETION") {
				$rxnTable->add_data($row,"ASSOCIATED PEG",$args->{pegs}->[$i],1);
			}
			$action = "adjusted";
		} else {
			if (defined($row)) {
				my $rowId = $rxnTable->row_index($row);
				$rxnTable->delete_row($rowId);
				$action = "adjusted";
			}
			$row = {
				LOAD => [$id],
				COMPARTMENT => [$args->{compartment}->[$i]],
				DIRECTIONALITY => [$sign],
				"ASSOCIATED PEG" => $args->{pegs}->[$i],
				SUBSYSTEM => $args->{subsystems}->[$i],
				CONFIDENCE => [$args->{confidences}->[$i]],
				NOTES => $args->{notes}->[$i],
				REFERENCE => $args->{references}->[$i]
			};
			$rxnTable->add_row($row);
			if (defined($args->{reason}) && $args->{reason} ne "NONE") {
				$rxnTable->add_data($row,"NOTES",$args->{reason},1);
			}
		}
		# remove all rows that contain same id and compartment
		my $rxnObj = $self->figmodel()->database()->get_object('rxnmdl',{
			'REACTION' => $id,
			'MODEL' => $self->id(),
			'compartment' => $args->{compartment}->[$i]
		});
		if(defined($rxnObj)) {
			$rxnObj->delete();
		}
		$rxnObj = $self->figmodel()->database()->create_object('rxnmdl',{
			REACTION => $row->{LOAD}->[0],
			MODEL => $self->id(),
			directionality => $row->{DIRECTIONALITY}->[0],
			compartment => $row->{COMPARTMENT}->[0],
			pegs => join("|",@{$row->{"ASSOCIATED PEG"}}),
			confidence => $row->{CONFIDENCE}->[0]
		});
		if (defined($rxnObj) && defined($row->{REFERENCE}->[0]) && $row->{REFERENCE}->[0] ne "NONE") {
			for (my $i=0; $i < @{$row->{REFERENCE}}; $i++) {
				my $refID = "NONE";
				if ($row->{REFERENCE}->[$i] =~ m/^PMID\d+$/) {
					$refID = $row->{REFERENCE}->[$i];
				}
				my $rxnObj = $self->figmodel()->database()->create_object('reference',{
					objectID => $rxnObj->_id(),
					DBENTITY => "rxnmdl",
					pubmedID => "NONE",
					notation => $row->{REFERENCE}->[$i],
					date => time()
				});
			}
		}
	}
	$rxnTable->save();
	$self->releaseModelLock();
	$self->reaction_table(1);
	#$self->processModel();
	return $args;
}
=head3 removeReactions
Definition:
	{}:Output = FIGMODELmodel->removeReactions({
		ids=>[string]:reaction IDs,
		compartments=>[string]:compartment, (defaults to c)
		reason=>string:reason for deletion, (defaults to NONE)
		user=>string:login of the user calling for the changes (defaults to model owner)
	});
	Output = {error=>string:error message} ({} returned on success)
Description:
=cut
sub removeReactions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["ids"],{
		compartments=>[],
		reason=>"NONE",
		user=>$self->owner(),
		trackChanges=>1,
	});
	# check editability, parsing of arguments
	return $self->error_message("Model ".$self->id()." is not editable!") if(not $self->isEditable());
	return $self->error_message({function=>"removeReactions",args=>$args}) if(defined($args->{error}));
	# generate hash of id.compartment => 1
	my $id_compartment_hash = {
		map { $args->{ids}->[$_].($args->{compartments}->[$_] || 'c') => 1 }
			0..(scalar(@{$args->{ids}})-1) }; 
	my $db = $self->figmodel()->database();
	my $rxn_mdls = $db->get_objects('rxnmdl', { MODEL => $self->id() });
	foreach my $rxnmdl (@$rxn_mdls) { 
		next unless(defined($id_compartment_hash->{$rxnmdl->REACTION().$rxnmdl->compartment()}));
		$rxnmdl->delete();
	}
	$self->reaction_table(1); # update reaction table
	return {};
}
=head 3 validateModelDirectory
Definition:
	0/1 = $model->validateModelDirectory($dir)
Description: 
	Checks that the model directory is properly formatted. This
	currently includes: presence of model-provenance data
	(biochemistry, mappings, features), and valid rxnmdl file
	if that exists.
	
	Returns 0 if directory is invalid, otherwise returns 1.
	
	If $dir is provided, validate that directory. Otherwise,
	validate the default model directory $model->directory().
=cut
sub validateModelDirectory {
	my ($self, $dir) = @_;
	my $errF = sub {
		my $msg = shift @_;
		return $self->error_message({function => 'validateModelDirectory', message => $msg});
	};
	$dir = $self->directory() unless defined($dir);
	return $errF->("base directory $dir missing") unless -d $dir; # no directory == fail
	my $subdirs = ['biochemistry/', 'mapping/', 'annotations/'];
	my $subfiles = [ ['compound.txt', 'reaction.txt', 'cpdals.txt', 'rxnals.txt'],
					 ['complex.txt', 'cpxrole.txt', 'rxncpx.txt'],
					 ['features.txt'],
				   ];
	for(my $i=0; $i<(@$subdirs); $i++) {
		my $subdir = $subdirs->[$i];
		return $errF->("$dir : subdirectory $subdir missing") unless -d $dir.$subdir; # no sub-directory == fail
		for(my $j=0; $j<(@{$subfiles->[$i]}); $j++) {
			my $file = $subfiles->[$i]->[$j];
			my $path = $dir.$subdir.$file;
			return $errF->("$dir : provanance file $path missing") unless(-f $path); # missing file == fail
			my $wc = `wc -l $path`;
			$wc =~ s/^(\d+).*/$1/g;
			return $errF->("$dir : provanance file $path empty") unless($wc > 1);  # file empty or only header == fail
		}
	}
	my $rxnmdl = $dir."rxnmdl.txt";
	if(-f $rxnmdl) {
		my $wc = `wc -l $rxnmdl`;
		$wc =~ s/^(\d+).*/$1/g;
		return $errF->("$dir : rxnmdl file exists and is empty") unless($wc > 1); 
	}
	return 1;	
}

=head2 Model Versioning Functions
=head3 Porcelain functions
checkpoint()
revert(id, x)
=cut
sub checkpoint {
	my ($self) = @_;
	return ModelSEED::FIGMODEL::FIGMODELERROR("Model is not editable!") if(!$self->isEditable());
	my $dir = $self->directory();
	$self->flatten($dir."rxnmdl.txt");
	$self->increment();
	$self->copyProvenanceFrom($dir); # now copy over provenance info to new version directory
}

sub revert { 
	my ($self, $version) = @_;
	return ModelSEED::FIGMODEL::FIGMODELERROR("Model is not editable!") if(!$self->isEditable());
	$version = "v$version" if($version =~ /^\d+$/);
	$version = $self->id().".".$version if ($version =~ /^v\d+$/);
	my $test = $self->figmodel()->get_model($version);
	unless(defined($test)) {
		return $self->figmodel()->error_message({message => "Unable to find model version $version! Doing nothing."});
	}
    if(!-d $self->config("database root directory")->[0]."tmp/") {
        mkdir $self->config("database root directory")->[0]."tmp/";
    }
	my ($fh, $tmpfile) = File::Temp::tempfile(
		"rxnmdl-".$self->id()."-".$self->version()."-XXXXXX",
		DIR => $self->config("database root directory")->[0]."tmp/");
	close($fh);
	my $curr_version = $self->version();
	$self->flatten($tmpfile);
	$self->restore($version, $curr_version);
}

=head3 Plumbing

=cut
sub copyProvenanceFrom {
	my ($self, $source) = @_;
	unless(-d $source) {
		return $self->error_message({ message => "Cannont find directory $source"});
	}
	my $target = $self->directory();
	if(!-d $target) {
		File::Path::make_path $target;
	}
	if(-d $source."biochemistry") {
		system("cp ".$source."biochemistry/* ".$target."biochemistry/");
		#File::Copy::Recursive::dircopy($source."biochemistry", $target."biochemistry");
	}
	if(-d $source."mapping") {
		system("cp ".$source."mapping/* ".$target."mapping/");
		#File::Copy::Recursive::dircopy($source."mapping", $target."mapping");
	}
	if(-d $source."annotations") {
		system("cp ".$source."annotations/* ".$target."annotations/");
		#File::Copy::Recursive::dircopy($source."annotations", $target."annotations");
	}
}

sub flatten {
	my ($self, $target) = @_;
	return ModelSEED::FIGMODEL::FIGMODELERROR("Model is not editable!") if(!$self->isEditable());
	my $db = $self->figmodel()->database();
	my $config = {
		filename => $target,
		hash_headings => [],
		delimiter => ";",
		item_delimiter => "|",
	};
	my $rxnmdls = $db->get_objects('rxnmdl', { MODEL => $self->id() });
	my $tbl = $db->ppo_rows_to_table($config, $rxnmdls);
	$tbl->save();
}

sub _drop_ppo_database {
	my ($self) = @_;
	return ModelSEED::FIGMODEL::FIGMODELERROR("Model is not editable!") if(!$self->isEditable());
	my $db = $self->figmodel()->database();
	my $rxn_mdls = $db->get_objects('rxnmdl',
		{ MODEL => $self->id() });
	foreach my $rxnmdl (@$rxn_mdls) {
		$rxnmdl->delete();
	}
	my $mdl = $db->get_object('model', { id => $self->id() });
	$mdl->delete() if($mdl);
}
	
sub increment {
	my ($self) = @_;		
	return ModelSEED::FIGMODEL::FIGMODELERROR("Model is not editable!") if(!$self->isEditable());
	my $hash = { map { $_ => $self->ppo()->$_() } keys %{$self->ppo()->attributes()} };
	my $parts = $self->parseId($self->fullId());
	$hash->{canonicalID} = $hash->{id};
	$hash->{id} = $parts->{full};
	my $obj = $self->db()->create_object("model_version", $hash);
	$self->ppo()->version($self->ppo()->version() + 1);
	$self->fullId($self->id()); # update id to unversioned copy (otherwise directory() will be wrong   
	delete $self->{_directory}; # reset directory cache
	unless(defined($obj)) {
		return $self->error_message({message => "Unable to create entry in model_version table!"});
	}
}

sub restore {
	my ($self, $versionToRestore, $finalVersionNumber) = @_;
	return ModelSEED::FIGMODEL::FIGMODELERROR("Model is not editable!") if(!$self->isEditable());
	my $mdl = $self->figmodel()->get_model($versionToRestore);
	if(!defined($mdl)) {
		return $self->error_message({message => "Model to restore $versionToRestore could not be found!", function => "restore"});
	}
	# do Model row object
	my $new_ppo = { map { $_ => $mdl->ppo()->$_() } keys %{$mdl->ppo()->attributes()} };
	delete $new_ppo->{canonicalID}; # canonicalID not in the MODEL table
	$new_ppo->{id} = $self->id(); # change model id to ours
	$self->_drop_ppo_database(); # delete current object now
	$self->figmodel()->database()->create_object('model', $new_ppo);
	# then do rxnmdl table
	my $rxn_mdls = $mdl->figmodel()->database()->get_objects('rxnmdl', { MODEL => $mdl->id() });
	foreach my $rxnmdl (@$rxn_mdls) {
		my $attrs = $rxnmdl->attributes();
		my $hash = { map { $_ => $rxnmdl->$_() } keys %$attrs };
		$hash->{MODEL} = $self->id(); # change model id to ours
		$self->figmodel()->database()->create_object('rxnmdl', $hash);
	}
	$self->ppo()->version($finalVersionNumber); 
}


=head2 Analysis Functions

=head3 run_microarray_analysis
Definition:
	int::status = FIGMODEL->run_microarray_analysis(string::media,string::job id,string::gene calls);
Description:
	Runs microarray analysis attempting to turn off genes that are inactive in the microarray
=cut
sub run_microarray_analysis {
	my ($self,$media,$label,$index,$genecall) = @_;
	$genecall =~ s/_/:/g;
	$genecall =~ s/\//;/g;
	my $uniqueFilename = $self->figmodel()->filename();
	my $command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($uniqueFilename,$self->id(),$media,["ProductionMFA","ShewenellaExperiment"],{"Microarray assertions" => $label.";".$index.";".$genecall,"MFASolver" => "CPLEX","Network output location" => "/scratch/"},"MicroarrayAnalysis-".$uniqueFilename.".txt",undef,$self->selected_version());
	system($command);
	my $filename = $self->figmodel()->config("MFAToolkit output directory")->[0].$uniqueFilename."/MicroarrayOutput-".$index.".txt";
	if (-e $filename) {
		my $output = $self->figmodel()->database()->load_single_column_file($filename);
		if (defined($output->[0])) {
			my @array = split(/;/,$output->[0]);
			$self->figmodel()->clearing_output($uniqueFilename,"MicroarrayAnalysis-".$uniqueFilename.".txt");
			return ($array[0],$array[1],$array[8].":".$array[2],$array[9].":".$array[3],$array[10].":".$array[4],$array[11].":".$array[5],$array[12].":".$array[6],$array[13].":".$array[7]);	
		}
		print STDERR $filename." is empty!";
	}
	print STDERR $filename." not found!";
	$self->figmodel()->clearing_output($uniqueFilename,"MicroarrayAnalysis-".$uniqueFilename.".txt");
	
	return undef;
}

=head3 find_minimal_pathways
Definition:
	int::status = FIGMODEL->find_minimal_pathways(string::media,string::objective);
Description:
	Runs microarray analysis attempting to turn off genes that are inactive in the microarray
=cut
sub find_minimal_pathways {
	my ($self,$media,$objective,$solutionnum,$AllReversible,$additionalexchange) = @_;

	#Setting default media
	if (!defined($media)) {
		$media = "Complete";
	}

	#Setting default solution number
	if (!defined($solutionnum)) {
		$solutionnum = "5";
	}

	#Setting additional exchange fluxes
	if (!defined($additionalexchange) || length($additionalexchange) == 0) {
		if ($self->id() eq "iAF1260") {
			$additionalexchange = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$additionalexchange = $self->figmodel()->config("default exchange fluxes")->[0];
		}
	}

	#Translating objective
	my $objectivestring;
	if ($objective eq "ALL") {
		#Getting the list of universal building blocks
		my $buildingblocks = $self->config("universal building blocks");
		my @objectives = keys(%{$buildingblocks});
		#Getting the nonuniversal building blocks
		my $otherbuildingblocks = $self->config("nonuniversal building blocks");
		my @array = keys(%{$otherbuildingblocks});
		if (defined($self->get_biomass()) && defined($self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0]))) {
			my $equation = $self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0])->{"EQUATION"}->[0];
			if (defined($equation)) {
				for (my $i=0; $i < @array; $i++) {
					if (CORE::index($equation,$array[$i]) > 0) {
						push(@objectives,$array[$i]);
					}
				}
			}
		}
		for (my $i=0; $i < @objectives; $i++) {
			$self->find_minimal_pathways($media,$objectives[$i]);
		}
		return;
	} elsif ($objective eq "ENERGY") {
		$objectivestring = "MAX;FLUX;rxn00062;c;1";
	} elsif ($objective =~ m/cpd\d\d\d\d\d/) {
		if ($objective =~ m/\[(\w)\]/) {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";".$1.";1";
			$additionalexchange .= ";".$objective."[".$1."]:-100:0";
		} else {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";c;1";
			$additionalexchange .= ";".$objective."[c]:-100:0";
		}
	} elsif ($objective =~ m/(rxn\d\d\d\d\d)/) {
		my ($Reactants,$Products) = $self->figmodel()->GetReactionSubstrateData($objective);
		for (my $i=0; $i < @{$Products};$i++) {
			my $temp = $Products->[$i]->{"DATABASE"}->[0];
			if ($additionalexchange !~ m/$temp/) {
				#$additionalexchange .= ";".$temp."[c]:-100:0";
			}
		}
		for (my $i=0; $i < @{$Reactants};$i++) {
			print $Reactants->[$i]->{"DATABASE"}->[0]." started\n";
			$self->find_minimal_pathways($media,$Reactants->[$i]->{"DATABASE"}->[0],$additionalexchange);
			print $Reactants->[$i]->{"DATABASE"}->[0]." done\n";
		}
		return;
	}

	#Adding additional drains
	if (($objective eq "cpd15665" || $objective eq "cpd15667" || $objective eq "cpd15668" || $objective eq "cpd15669") && $additionalexchange !~ m/cpd15666/) {
		$additionalexchange .= ";cpd15666[c]:0:100";
	} elsif ($objective eq "cpd11493" && $additionalexchange !~ m/cpd12370/) {
		$additionalexchange .= ";cpd12370[c]:0:100";
	} elsif ($objective eq "cpd00166" && $additionalexchange !~ m/cpd01997/) {
		$additionalexchange .= ";cpd01997[c]:0:100;cpd03422[c]:0:100";
	}

	#Running MFAToolkit
	my $filename = $self->figmodel()->filename();
	my $command;
	if (defined($AllReversible) && $AllReversible == 1) {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"Make all reactions reversible in MFA"=>1, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "CPLEX","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	} else {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"Make all reactions reversible in MFA"=>0, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "CPLEX","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	}
	system($command);

	#Loading problem report
	my $results = $self->figmodel()->LoadProblemReport($filename);
	#Clearing output
	$self->figmodel()->clearing_output($filename,"MinimalPathways-".$media."-".$self->id()."-".$objective.".txt");
	if (!defined($results)) {
		print STDERR $objective." pathway results not found!\n";
		return;
	}

	#Parsing output
	my @Array;
	my $row = $results->get_row(1);
	if (defined($row->{"Notes"}->[0])) {
		$_ = $row->{"Notes"}->[0];
		@Array = /\d+:([^\|]+)\|/g;
	}
	
	#Writing output to file
	$self->figmodel()->database()->print_array_to_file($self->directory()."MinimalPathways-".$media."-".$objective."-".$self->id()."-".$AllReversible."-".$self->selected_version().".txt",[join("|",@Array)]);
}

=head3 find_minimal_pathways
Definition:
	int::status = FIGMODEL->find_minimal_pathways(string::media,string::objective);
Description:
	Runs microarray analysis attempting to turn off genes that are inactive in the microarray
=cut
sub find_minimal_pathways_two {
	my ($self,$media,$objective,$solutionnum,$AllReversible,$additionalexchange) = @_;

	#Setting default media
	if (!defined($media)) {
		$media = "Complete";
	}

	#Setting default solution number
	if (!defined($solutionnum)) {
		$solutionnum = "5";
	}

	#Setting additional exchange fluxes
	if (!defined($additionalexchange) || length($additionalexchange) == 0) {
		if ($self->id() eq "iAF1260") {
			$additionalexchange = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$additionalexchange = $self->figmodel()->config("default exchange fluxes")->[0];
		}
	}

	#Translating objective
	my $objectivestring;
	if ($objective eq "ALL") {
		#Getting the list of universal building blocks
		my $buildingblocks = $self->config("universal building blocks");
		my @objectives = keys(%{$buildingblocks});
		#Getting the nonuniversal building blocks
		my $otherbuildingblocks = $self->config("nonuniversal building blocks");
		my @array = keys(%{$otherbuildingblocks});
		if (defined($self->get_biomass()) && defined($self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0]))) {
			my $equation = $self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0])->{"EQUATION"}->[0];
			if (defined($equation)) {
				for (my $i=0; $i < @array; $i++) {
					if (CORE::index($equation,$array[$i]) > 0) {
						push(@objectives,$array[$i]);
					}
				}
			}
		}
		for (my $i=0; $i < @objectives; $i++) {
			$self->find_minimal_pathways($media,$objectives[$i]);
		}
		return;
	} elsif ($objective eq "ENERGY") {
		$objectivestring = "MAX;FLUX;rxn00062;c;1";
	} elsif ($objective =~ m/cpd\d\d\d\d\d/) {
		if ($objective =~ m/\[(\w)\]/) {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";".$1.";1";
			$additionalexchange .= ";".$objective."[".$1."]:-100:0";
		} else {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";c;1";
			$additionalexchange .= ";".$objective."[c]:-100:0";
		}
	} elsif ($objective =~ m/(rxn\d\d\d\d\d)/) {
		my ($Reactants,$Products) = $self->figmodel()->GetReactionSubstrateData($objective);
		for (my $i=0; $i < @{$Products};$i++) {
			my $temp = $Products->[$i]->{"DATABASE"}->[0];
			if ($additionalexchange !~ m/$temp/) {
				#$additionalexchange .= ";".$temp."[c]:-100:0";
			}
		}
		for (my $i=0; $i < @{$Reactants};$i++) {
			print $Reactants->[$i]->{"DATABASE"}->[0]." started\n";
			$self->find_minimal_pathways($media,$Reactants->[$i]->{"DATABASE"}->[0],$additionalexchange);
			print $Reactants->[$i]->{"DATABASE"}->[0]." done\n";
		}
		return;
	}

	#Adding additional drains
	if (($objective eq "cpd15665" || $objective eq "cpd15667" || $objective eq "cpd15668" || $objective eq "cpd15669") && $additionalexchange !~ m/cpd15666/) {
		$additionalexchange .= ";cpd15666[c]:0:100";
	} elsif ($objective eq "cpd11493" && $additionalexchange !~ m/cpd12370/) {
		$additionalexchange .= ";cpd12370[c]:0:100";
	} elsif ($objective eq "cpd00166" && $additionalexchange !~ m/cpd01997/) {
		$additionalexchange .= ";cpd01997[c]:0:100;cpd03422[c]:0:100";
	}

	#Running MFAToolkit
	my $filename = $self->figmodel()->filename();
	my $command;
	if (defined($AllReversible) && $AllReversible == 1) {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"use simple variable and constraint names"=>1,"Make all reactions reversible in MFA"=>1, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "SCIP","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	} else {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"use simple variable and constraint names"=>1,"Make all reactions reversible in MFA"=>0, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "SCIP","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	}
	print $command."\n";
	system($command);

	#Loading problem report
	my $results = $self->figmodel()->LoadProblemReport($filename);
	#Clearing output
	$self->figmodel()->clearing_output($filename,"MinimalPathways-".$media."-".$self->id()."-".$objective.".txt");
	if (!defined($results)) {
		print STDERR $objective." pathway results not found!\n";
		return;
	}

	#Parsing output
	my @Array;
	my $row = $results->get_row(1);
	if (defined($row->{"Notes"}->[0])) {
		$_ = $row->{"Notes"}->[0];
		@Array = /\d+:([^\|]+)\|/g;
	}
	
	#Writing output to file
	$self->figmodel()->database()->print_array_to_file($self->directory()."MinimalPathways-".$media."-".$objective."-".$self->id()."-".$AllReversible."-".$self->selected_version().".txt",[join("|",@Array)]);
}

sub combine_minimal_pathways {
	my ($self) = @_;
	
	my $tbl;
	if (-e $self->directory()."MinimalPathwayTable-".$self->id().$self->selected_version().".tbl") {
		$tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."MinimalPathwayTable-".$self->id().$self->selected_version().".tbl",";","|",0,["Objective","Media","Reversible"]);
	} else {
		$tbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Objective","Media","Reactions","Reversible","Shortest path","Number of essentials","Essentials","Length"],$self->directory()."MinimalPathwayTable-".$self->id().$self->selected_version().".tbl",["Objective","Media","Reversible"],";","|");
	}
	my @files = glob($self->directory()."MinimalPathways-*");
	for (my $i=0; $i < @files;$i++) {
		if ($files[$i] =~ m/MinimalPathways\-(\S+)\-(cpd\d\d\d\d\d)\-(\w+)\-(\d)\-/ || $files[$i] =~ m/MinimalPathways\-(\S+)\-(ENERGY)\-(\w+)\-(\d)\-/) {
			my $reactions = $self->figmodel()->database()->load_single_column_file($files[$i],"");
			if (defined($reactions) && @{$reactions} > 0 && length($reactions->[0]) > 0) {
				my $newrow = {"Objective"=>[$2],"Media"=>[$1],"Reversible"=>[$4]};
				my $row = $tbl->get_table_by_key($newrow->{"Objective"}->[0],"Objective")->get_table_by_key($newrow->{"Media"}->[0],"Media")->get_row_by_key($newrow->{"Reversible"}->[0],"Reversible");
				if (!defined($row)) {
					$row = $tbl->add_row($newrow);
				}
				$row->{Reactions} = $self->figmodel()->database()->load_single_column_file($files[$i],"");
				delete($row->{"Shortest path"});
				delete($row->{"Number of essentials"});
				delete($row->{"Essentials"});
				delete($row->{"Length"});
				for (my $j=0; $j < @{$row->{Reactions}}; $j++) {
					my @array = split(/,/,$row->{Reactions}->[$j]);
					$row->{"Length"}->[$j] = @array;
					if (!defined($row->{"Shortest path"}->[0]) || $row->{"Length"}->[$j] < $row->{"Shortest path"}->[0]) {
						$row->{"Shortest path"}->[0] = $row->{"Length"}->[$j];
					}
					$row->{"Number of essentials"}->[0] = 0;
					for (my $k=0; $k < @array;$k++) {
						if ($array[$k] =~ m/(rxn\d\d\d\d\d)/) {
							my $class = $self->get_reaction_class($1,1);
							my $temp = $row->{Media}->[0].":Essential";
							if ($class =~ m/$temp/) {
								$row->{"Number of essentials"}->[$j]++;
								if (!defined($row->{"Essentials"}->[$j]) && length($row->{"Essentials"}->[$j]) > 0) {
									$row->{"Essentials"}->[$j] = $array[$k];
								} else {
									$row->{"Essentials"}->[$j] .= ",".$array[$k];
								}
							}
						}
					}
				}
			}
		}
	}
	$tbl->save();	
}

=head3 GetSimulationJobTable
Definition:
	my $JobTable = $model->GetSimulationJobTable($Experiment,$PrintResults,$Version);
Description:
=cut

sub GetSimulationJobTable {
	my ($self,$SimulationTable,$Experiment,$Folder) = @_;

	#Determing the simulations that need to be run
	if (!defined($SimulationTable)) {
		$SimulationTable = $self->figmodel()->GetExperimentalDataTable($self->genome(),$Experiment);
		if (!defined($SimulationTable)) {
			return undef;
		}
	}

	#Creating the job table
	my $JobTable = $self->figmodel()->CreateJobTable($Folder);
	for (my $i=0; $i < $SimulationTable->size(); $i++) {
		if ($SimulationTable->get_row($i)->{"Heading"}->[0] =~ m/Gene\sKO/) {
			my $Row = $JobTable->get_row_by_key("Gene KO","LABEL",1);
			$JobTable->add_data($Row,"MEDIA",$SimulationTable->get_row($i)->{"Media"}->[0],1);
		} elsif ($SimulationTable->get_row($i)->{"Heading"}->[0] =~ m/Media\sgrowth/) {
			my $Row = $JobTable->get_row_by_key("Growth phenotype","LABEL",1);
			$JobTable->add_data($Row,"MEDIA",$SimulationTable->get_row($i)->{"Media"}->[0],1);
		} elsif ($SimulationTable->get_row($i)->{"Heading"}->[0] =~ m/Interval\sKO/) {
			my $Row = $JobTable->get_row_by_key($SimulationTable->get_row($i)->{"Heading"}->[0],"LABEL",1);
			$JobTable->add_data($Row,"MEDIA",$SimulationTable->get_row($i)->{"Media"}->[0],1);
			$JobTable->add_data($Row,"GENE KO",$SimulationTable->get_row($i)->{"Experiment type"}->[0],1);
		}
	}

	#Filling in model specific elements of the job table
	for (my $i=0; $i < $JobTable->size(); $i++) {
		if ($JobTable->get_row($i)->{"LABEL"}->[0] =~ m/Gene\sKO/) {
			$JobTable->get_row($i)->{"RUNTYPE"}->[0] = "SINGLEKO";
			$JobTable->get_row($i)->{"SAVE NONESSENTIALS"}->[0] = 1;
		} else {
			$JobTable->get_row($i)->{"RUNTYPE"}->[0] = "GROWTH";
			$JobTable->get_row($i)->{"SAVE NONESSENTIALS"}->[0] = 0;
		}
		$JobTable->get_row($i)->{"LP FILE"}->[0] = $self->directory()."FBA-".$self->id().$self->selected_version();
		$JobTable->get_row($i)->{"MODEL"}->[0] = $self->directory().$self->id().$self->selected_version().".txt";
		$JobTable->get_row($i)->{"SAVE FLUXES"}->[0] = 0;
	}

	return $JobTable;
}

=head3 EvaluateSimulationResults
Definition:
	(integer::false positives,integer::false negatives,integer::correct negatives,integer::correct positives,string::error vector,string heading vector,FIGMODELtable::simulation results) = FIGMODELmodel->EvaluateSimulationResults(FIGMODELtable::raw simulation results,FIGMODELtable::experimental data);
Description:
	Compares simulation results with experimental data to produce a table indicating where predictions are incorrect.
=cut

sub EvaluateSimulationResults {
	my ($self,$Results,$ExperimentalDataTable) = @_;

	#Comparing experimental results with simulation results
	my $SimulationResults = ModelSEED::FIGMODEL::FIGMODELTable->new(["Run result","Experiment type","Media","Experiment ID","Reactions knocked out"],$self->directory()."SimulationOutput".$self->id().$self->selected_version().".txt",["Experiment ID","Media"],"\t",",",undef);
	my $FalsePostives = 0;
	my $FalseNegatives = 0;
	my $CorrectNegatives = 0;
	my $CorrectPositives = 0;
	my @Errorvector;
	my @HeadingVector;
	my $ReactionKOWithGeneHash;
	for (my $i=0; $i < $Results->size(); $i++) {
		if ($Results->get_row($i)->{"LABEL"}->[0] eq "Gene KO") {
			if (defined($Results->get_row($i)->{"REACTION KO WITH GENES"})) {
				for (my $j=0; $j < @{$Results->get_row($i)->{"REACTION KO WITH GENES"}}; $j++) {
					my @Temp = split(/:/,$Results->get_row($i)->{"REACTION KO WITH GENES"}->[$j]);
					if (defined($Temp[1]) && length($Temp[1]) > 0) {
						$ReactionKOWithGeneHash->{$Temp[0]} = $Temp[1];
					}
				}
			}
			if ($Results->get_row($i)->{"OBJECTIVE"}->[0] == 0) {
				for (my $j=0; $j < @{$Results->get_row($i)->{"NONESSENTIALGENES"}}; $j++) {
					my $Row = $ExperimentalDataTable->get_row_by_key("Gene KO:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j],"Heading");
					if (defined($Row)) {
						my $KOReactions = "none";
						if (defined($ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]})) {
							$KOReactions = $ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]};
						}
						push(@HeadingVector,$Row->{"Heading"}->[0].":".$KOReactions);
						my $Status = "Unknown";
						if ($Row->{"Growth"}->[0] > 0) {
							$Status = "False negative";
							$FalseNegatives++;
							push(@Errorvector,3);
						} else {
							$Status = "False positive";
							$FalsePostives++;
							push(@Errorvector,2);
						}
						$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Gene KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => [$KOReactions]});
					}
				}
			} else {
				for (my $j=0; $j < @{$Results->get_row($i)->{"ESSENTIALGENES"}}; $j++) {
					#print $j."\t".$Results->get_row($i)->{"ESSENTIALGENES"}->[$j]."\n";
					my $Row = $ExperimentalDataTable->get_row_by_key("Gene KO:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"ESSENTIALGENES"}->[$j],"Heading");
					if (defined($Row)) {
						my $KOReactions = "none";
						if (defined($ReactionKOWithGeneHash->{$Results->get_row($i)->{"ESSENTIALGENES"}->[$j]})) {
							$KOReactions = $ReactionKOWithGeneHash->{$Results->get_row($i)->{"ESSENTIALGENES"}->[$j]};
						}
						push(@HeadingVector,$Row->{"Heading"}->[0].":".$KOReactions);
						my $Status = "Unknown";
						if ($Row->{"Growth"}->[0] > 0) {
							$Status = "False negative";
							$FalseNegatives++;
							push(@Errorvector,3);
						} else {
							$Status = "Correct negative";
							$CorrectNegatives++;
							push(@Errorvector,1);
						}
						$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Gene KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => [$KOReactions]});
					}
				}
				for (my $j=0; $j < @{$Results->get_row($i)->{"NONESSENTIALGENES"}}; $j++) {
					my $Row = $ExperimentalDataTable->get_row_by_key("Gene KO:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j],"Heading");
					if (defined($Row)) {
						my $KOReactions = "none";
						if (defined($ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]})) {
							$KOReactions = $ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]};
						}
						push(@HeadingVector,$Row->{"Heading"}->[0].":".$KOReactions);
						my $Status = "Unknown";
						if ($Row->{"Growth"}->[0] > 0) {
							$Status = "Correct positive";
							$CorrectPositives++;
							push(@Errorvector,0);
						} else {
							$Status = "False positive";
							$FalsePostives++;
							push(@Errorvector,2);
						}
						$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Gene KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => [$KOReactions]});
					}
				}
			}
		} elsif ($Results->get_row($i)->{"LABEL"}->[0] eq "Growth phenotype") {
			my $Row = $ExperimentalDataTable->get_row_by_key("Media growth:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"MEDIA"}->[0],"Heading");
			if (defined($Row)) {
				push(@HeadingVector,$Row->{"Heading"}->[0].":none");
				my $Status = "Unknown";
				if ($Row->{"Growth"}->[0] > 0) {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "Correct positive";
						$CorrectPositives++;
						push(@Errorvector,0);
					} else {
						$Status = "False negative";
						$FalseNegatives++;
						push(@Errorvector,3);
					}
				} else {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "False positive";
						$FalsePostives++;
						push(@Errorvector,2);
					} else {
						$Status = "Correct negative";
						$CorrectNegatives++;
						push(@Errorvector,1);
					}
				}
				$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Media growth"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Media"}->[0]],"Reactions knocked out" => ["none"]});
			}
		} elsif ($Results->get_row($i)->{"LABEL"}->[0] =~ m/Interval\sKO/ && defined($Results->get_row($i)->{"KOGENES"}->[0])) {
			my $Row = $ExperimentalDataTable->get_row_by_key($Results->get_row($i)->{"LABEL"}->[0],"Heading");
			if (defined($Row)) {
				my $Status = "Unknown";
				if ($Row->{"Growth"}->[0] > 0) {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "Correct positive";
						$CorrectPositives++;
						push(@Errorvector,0);
					} else {
						$Status = "False negative";
						$FalseNegatives++;
						push(@Errorvector,3);
					}
				} else {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "False positive";
						$FalsePostives++;
						push(@Errorvector,2);
					} else {
						$Status = "Correct negative";
						$CorrectNegatives++;
						push(@Errorvector,1);
					}
				}
				$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Interval KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => ["none"]});
			}
		}
	}

	return ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,join(";",@Errorvector),join(";",@HeadingVector),$SimulationResults);
}



=head3 GapFillingAlgorithm

Definition:
	FIGMODELmodel->GapFillingAlgorithm();

Description:
	This is a wrapper for running the gap filling algorithm on any model in the database.
	The algorithm performs a gap filling for any false negative prediction of the avialable experimental data.
	This function is threaded to improve efficiency: one thread does nothing but using the MFAToolkit to fill gaps for every false negative prediction.
	The other thread reads in the gap filling solutions, builds a test model for each solution, and runs the test model against all available experimental data.
	This function prints two important output files in the Model directory:
	1.) GapFillingOutput.txt: this is a summary of the results of the gap filling analysis
	2.) GapFillingErrorMatrix.txt: this lists the correct and incorrect predictions for each gapfilling solution implemented in a test model.
=cut

sub GapFillingAlgorithm {
	my ($self) = @_;

	#First the input model version and model filename should be simulated and the false negatives identified
	my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->RunAllStudiesWithDataFast("All");

	#Getting the filename
	my $UniqueFilename = $self->figmodel()->filename();

	#Printing the original performance vector
	$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-OPEM".".txt",[$HeadingVector,$Errorvector]);

	my $PreviousGapFilling;
	if (-e $self->directory().$self->id().$self->selected_version()."-GFS.txt") {
		#Backing up the old solution file
		system("cp ".$self->directory().$self->id().$self->selected_version()."-GFS.txt ".$self->directory().$self->id().$self->selected_version()."-OldGFS.txt");
		unlink($self->directory().$self->id().$self->selected_version()."-GFS.txt");
	}
	if (-e $self->directory().$self->id().$self->selected_version()."-OldGFS.txt") {
		#Reading in the solution file from the previous gap filling if it exists
		$PreviousGapFilling = $self->figmodel()->database()->load_table($self->directory().$self->id().$self->selected_version()."-OldGFS.txt",";",",",0,["Experiment"]);
	}

	#Now we use the simulation output to make the gap filling run data
	my @Errors = split(/;/,$Errorvector);
	my @Headings = split(/;/,$HeadingVector);
	my $GapFillingRunSpecs = "";
	my $Count = 0;
	my $RescuedPreviousResults;
	my $RunCount = 0;
	my $SolutionExistedCount = 0;
	my $AcceptedSolutions = 0;
	my $RejectedSolutions = 0;
	my $NoExistingSolutions = 0;
	for (my $i=0; $i < @Errors; $i++) {
		if ($Errors[$i] == 3) {
			my @HeadingDataArray = split(/:/,$Headings[$i]);
			if ($HeadingDataArray[2] !~ m/^peg\./ || $HeadingDataArray[3] ne "none") {
				my $SolutionFound = 0;
				if (defined($PreviousGapFilling) && defined($PreviousGapFilling->get_row_by_key($HeadingDataArray[2],"Experiment"))) {
					my @Rows = $PreviousGapFilling->get_rows_by_key($HeadingDataArray[2],"Experiment");
					for (my $j=0; $j < @Rows; $j++) {
						if ($HeadingDataArray[2] =~ m/^peg\./) {
							my $ReactionList = $self->InspectSolution($HeadingDataArray[2],$HeadingDataArray[1],$Rows[$j]->{"Solution reactions"});
							if (defined($ReactionList)) {
								print join(",",@{$Rows[$j]->{"Solution reactions"}})."\t".join(",",@{$ReactionList})."\n";
								$SolutionFound++;
								push(@{$RescuedPreviousResults},$Rows[$j]->{"Experiment"}->[0].";".$Rows[$j]->{"Solution index"}->[0].";".$Rows[$j]->{"Solution cost"}->[0].";".join(",",@{$ReactionList}));
								$AcceptedSolutions++;
							} else {
								$RejectedSolutions++;
							}
						} else {
							my $ReactionList = $self->InspectSolution($HeadingDataArray[2],$HeadingDataArray[1],$Rows[$j]->{"Solution reactions"});
							if (defined($ReactionList)) {
								print join(",",@{$Rows[$j]->{"Solution reactions"}})."\t".join(",",@{$ReactionList})."\n";
								$SolutionFound++;
								push(@{$RescuedPreviousResults},$Rows[$j]->{"Experiment"}->[0].";".$Rows[$j]->{"Solution index"}->[0].";".$Rows[$j]->{"Solution cost"}->[0].";".join(",",@{$ReactionList}));
								$AcceptedSolutions++;
							} else {
								$RejectedSolutions++;
							}
						}
					}
				} else {
					$NoExistingSolutions++;
				}
				if ($SolutionFound == 0) {
					$RunCount++;
					if (length($GapFillingRunSpecs) > 0) {
						$GapFillingRunSpecs .= ";";
					}
					$GapFillingRunSpecs .= $HeadingDataArray[2].":".$HeadingDataArray[1].":".$HeadingDataArray[3];
				} else {
					$SolutionExistedCount++;
				}
			}
			$Count++;
		}
	}

	#Updating the growmatch progress table
	my $Row = $self->figmodel()->database()->get_row_by_key("GROWMATCH TABLE",$self->genome(),"ORGANISM",1);
	$Row->{"INITIAL FP"}->[0] = $FalsePostives;
	$Row->{"INITIAL FN"}->[0] = $FalseNegatives;
	$Row->{"GF TIMING"}->[0] = time()."-";
	$Row->{"FN WITH SOL"}->[0] = $FalseNegatives-$NoExistingSolutions;
	$Row->{"FN WITH ACCEPTED SOL"}->[0] = $SolutionExistedCount;
	$Row->{"TOTAL ACCEPTED GF SOL"}->[0] = $AcceptedSolutions;
	$Row->{"TOTAL REJECTED GF SOL"}->[0] = $RejectedSolutions;
	$Row->{"FN WITH NO SOL"}->[0] = $NoExistingSolutions+$RejectedSolutions;
	$self->figmodel()->database()->update_row("GROWMATCH TABLE",$Row,"ORGANISM");

	#Running the gap filling once to correct all false negative errors
	my $SolutionsFound = 0;
	my $GapFillingArray;
	push(@{$GapFillingArray},split(/;/,$GapFillingRunSpecs));
	my $GapFillingResults = $self->datagapfill($GapFillingArray,"GFS");
	if (defined($GapFillingResults)) {
		$SolutionsFound = 1;
	}

	if (defined($RescuedPreviousResults) && @{$RescuedPreviousResults} > 0) {
		#Printing previous solutions to GFS file
		$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-GFS.txt",$RescuedPreviousResults,1);
		$SolutionsFound = 1;
	}

	#Recording the finishing of the gapfilling
	$Row = $self->figmodel()->database()->get_row_by_key("GROWMATCH TABLE",$self->genome(),"ORGANISM",1);
	$Row->{"GF TIMING"}->[0] .= time();
	$self->figmodel()->database()->update_row("GROWMATCH TABLE",$Row,"ORGANISM");

	if ($SolutionsFound == 1) {
		#Scheduling solution testing
		$self->figmodel()->add_job_to_queue({command => "testsolutions?".$self->id().$self->selected_version()."?-1?GF",user => $self->owner(),queue => "short"});
	} else {
		$self->error_message({function => "GapFillingAlgorithm",message => "No false negative predictions found. Data gap filling not necessary!"});
	}

	return $self->figmodel()->success();
}

=head3 SolutionReconciliation
Definition:
	FIGMODELmodel->SolutionReconciliation();
Description:
	This is a wrapper for running the solution reconciliation algorithm on any model in the database.
	The algorithm performs a reconciliation of any gap filling solutions to identify the combination of solutions that results in the optimal model.
	This function prints out one output file in the Model directory: ReconciliationOutput.txt: this is a summary of the results of the reconciliation analysis
=cut

sub SolutionReconciliation {
	my ($self,$GapFill,$Stage) = @_;

	#Setting the output filenames
	my $OutputFilename;
	my $OutputFilenameTwo;
	if ($GapFill == 1) {
		$OutputFilename = $self->directory().$self->id().$self->selected_version()."-GFReconciliation.txt";
		$OutputFilenameTwo = $self->directory().$self->id().$self->selected_version()."-GFSRS.txt";
	} else {
		$OutputFilename = $self->directory().$self->id().$self->selected_version()."-GGReconciliation.txt";
		$OutputFilenameTwo = $self->directory().$self->id().$self->selected_version()."-GGSRS.txt";
	}

	#In stage one, we run the reconciliation and create a test file to check combined solution performance
	if (!defined($Stage) || $Stage == 1) {
		my $GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		my $Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECONCILATION TIMING"}->[0] = time()."-";
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");

		#Getting a unique filename
		my $UniqueFilename = $self->figmodel()->filename();

		#Copying over the necessary files
		if ($GapFill == 1) {
			if (!-e $self->directory().$self->id().$self->selected_version()."-GFEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-GFEM.txt file not found. Could not reconcile!";
				return 0;
			}
			if (!-e $self->directory().$self->id().$self->selected_version()."-OPEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-OPEM.txt file not found. Could not reconcile!";
				return 0;
			}
			system("cp ".$self->directory().$self->id().$self->selected_version()."-GFEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-GFEM.txt");
			system("cp ".$self->directory().$self->id().$self->selected_version()."-OPEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-OPEM.txt");
			#Backing up and deleting the existing reconciliation file
			if (-e $OutputFilename) {
				system("cp ".$OutputFilename." ".$self->directory().$self->id().$self->selected_version()."-OldGFReconciliation.txt");
				unlink($OutputFilename);
			}
		} else {
			if (!-e $self->directory().$self->id().$self->selected_version()."-GGEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-GGEM.txt file not found. Could not reconcile!";
				return 0;
			}
			if (!-e $self->directory().$self->id().$self->selected_version()."-GGOPEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-GGOPEM.txt file not found. Could not reconcile!";
				return 0;
			}
			system("cp ".$self->directory().$self->id().$self->selected_version()."-GGEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-GGEM.txt");
			system("cp ".$self->directory().$self->id().$self->selected_version()."-GGOPEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-OPEM.txt");
			#Backing up and deleting the existing reconciliation file
			if (-e $OutputFilename) {
				system("cp ".$OutputFilename." ".$self->directory().$self->id().$self->selected_version()."-OldGGReconciliation.txt");
				unlink($OutputFilename);
			}
		}

		#Running the reconciliation
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),"NONE",["SolutionReconciliation"],{"Solution data for model optimization" => $UniqueFilename},"Reconciliation".$UniqueFilename.".log",undef,$self->selected_version()));
		$GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		$Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECONCILATION TIMING"}->[0] .= time();
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");

		#Loading the problem report from the reconciliation run
		my $ReconciliatonOutput = $self->figmodel()->LoadProblemReport($UniqueFilename);
		print $UniqueFilename."\n";
		#Clearing output files
		$self->figmodel()->clearing_output($UniqueFilename,"Reconciliation".$UniqueFilename.".log");
		$ReconciliatonOutput->save("/home/chenry/Test.txt");

		#Checking the a problem report was found and was loaded
		if (!defined($ReconciliatonOutput) || $ReconciliatonOutput->size() < 1 || !defined($ReconciliatonOutput->get_row(0)->{"Notes"}->[0])) {
			print STDERR "FIGMODEL:SolutionReconciliation: MFAToolkit output from SolutionReconciliation of ".$self->id()." not found!\n\n";
			return 0;
		}

		#Processing the solutions
		my $SolutionCount = 0;
		my $ReactionSetHash;
		my $SingleReactionHash;
		my $ReactionDataHash;
		for (my $n=0; $n < $ReconciliatonOutput->size(); $n++) {
			if (defined($ReconciliatonOutput->get_row($n)->{"Notes"}->[0]) && $ReconciliatonOutput->get_row($n)->{"Notes"}->[0] =~ m/^Recursive\sMILP\s([^;]+)/) {
				#Breaking up the solution into reaction sets
				my @ReactionSets = split(/\|/,$1);
				#Creating reaction lists for each set
				my $SolutionHash;
				for (my $i=0; $i < @ReactionSets; $i++) {
					if (length($ReactionSets[$i]) > 0) {
						my @Alternatives = split(/:/,$ReactionSets[$i]);
						for (my $j=1; $j < @Alternatives; $j++) {
							if (length($Alternatives[$j]) > 0) {
								push(@{$SolutionHash->{$Alternatives[$j]}},$Alternatives[0]);
							}
						}
						if (@Alternatives == 1) {
							$SingleReactionHash->{$Alternatives[0]}->{$SolutionCount} = 1;
							if (!defined($SingleReactionHash->{$Alternatives[0]}->{"COUNT"})) {
								$SingleReactionHash->{$Alternatives[0]}->{"COUNT"} = 0;
							}
							$SingleReactionHash->{$Alternatives[0]}->{"COUNT"}++;
						}
					}
				}
				#Identifying reactions sets and storing the sets in the reactions set hash
				foreach my $Solution (keys(%{$SolutionHash})) {
					my $SetKey = join(",",sort(@{$SolutionHash->{$Solution}}));
					if (!defined($ReactionSetHash->{$SetKey}->{$SetKey}->{$SolutionCount})) {
						$ReactionSetHash->{$SetKey}->{$SetKey}->{$SolutionCount} = 1;
						if (!defined($ReactionSetHash->{$SetKey}->{$SetKey}->{"COUNT"})) {
							$ReactionSetHash->{$SetKey}->{$SetKey}->{"COUNT"} = 0;
						}
						$ReactionSetHash->{$SetKey}->{$SetKey}->{"COUNT"}++;
					}
					$ReactionSetHash->{$SetKey}->{$Solution}->{$SolutionCount} = 1;
					if (!defined($ReactionSetHash->{$SetKey}->{$Solution}->{"COUNT"})) {
						$ReactionSetHash->{$SetKey}->{$Solution}->{"COUNT"} = 0;
					}
					$ReactionSetHash->{$SetKey}->{$Solution}->{"COUNT"}++;
				}
				$SolutionCount++;
			}
		}

		#Handling the scenario where no solutions were found
		if ($SolutionCount == 0) {
			print STDERR "FIGMODEL:SolutionReconciliation: Reconciliation unsuccessful. No solution found.\n\n";
			return 0;
		}

		#Printing results without solution performance figures. Also printing solution test file
		open (RECONCILIATION, ">$OutputFilename");
		#Printing the file heading
		print RECONCILIATION "DATABASE;DEFINITION;REVERSIBLITY;DELTAG;DIRECTION;NUMBER OF SOLUTIONS";
		for (my $i=0; $i < $SolutionCount; $i++) {
			print RECONCILIATION ";Solution ".$i;
		}
		print RECONCILIATION "\n";
		#Printing the singlet reactions first
		my $Solutions;
		print RECONCILIATION "SINGLET REACTIONS\n";
		 my @SingletReactions = keys(%{$SingleReactionHash});
		for (my $j=0; $j < $SolutionCount; $j++) {
			$Solutions->[$j]->{"BASE"} = $j;
		}
		for (my $i=0; $i < @SingletReactions; $i++) {
			my $ReactionData;
			if (defined($ReactionDataHash->{$SingletReactions[$i]})) {
				$ReactionData = $ReactionDataHash->{$SingletReactions[$i]};
			} else {
				my $Direction = substr($SingletReactions[$i],0,1);
				if ($Direction eq "+") {
					$Direction = "=>";
				} else {
					$Direction = "<=";
				}
				my $Reaction = substr($SingletReactions[$i],1);
				$ReactionData = FIGMODELObject->load($self->figmodel()->config("reaction directory")->[0].$Reaction,"\t");
				$ReactionData->{"DIRECTIONS"}->[0] = $Direction;
				$ReactionData->{"REACTIONS"}->[0] = $Reaction;
				if (!defined($ReactionData->{"DEFINITION"}->[0])) {
					$ReactionData->{"DEFINITION"}->[0] = "UNKNOWN";
				}
				if (!defined($ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0])) {
					$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0] = "UNKNOWN";
				}
				if (!defined($ReactionData->{"DELTAG"}->[0])) {
					$ReactionData->{"DELTAG"}->[0] = "UNKNOWN";
				}
				$ReactionDataHash->{$SingletReactions[$i]} = $ReactionData;
			}
			print RECONCILIATION $ReactionData->{"REACTIONS"}->[0].";".$ReactionData->{"DEFINITION"}->[0].";".$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0].";".$ReactionData->{"DELTAG"}->[0].";".$ReactionData->{"DIRECTIONS"}->[0].";".$SingleReactionHash->{$SingletReactions[$i]}->{"COUNT"};
			for (my $j=0; $j < $SolutionCount; $j++) {
				print RECONCILIATION ";";
				if (defined($SingleReactionHash->{$SingletReactions[$i]}->{$j})) {
					$Solutions->[$j]->{$SingletReactions[$i]} = 1;
					$Solutions->[$j]->{"BASE"} = $j;
					print RECONCILIATION "|".$j."|";
				}
			}
			print RECONCILIATION "\n";
		}
		#Printing the reaction sets with alternatives
		print RECONCILIATION "Reaction sets with alternatives\n";
		my @ReactionSets = keys(%{$ReactionSetHash});
		foreach my $ReactionSet (@ReactionSets) {
			my $NewSolutions;
			my $BaseReactions;
			my $AltList = [$ReactionSet];
			push(@{$AltList},keys(%{$ReactionSetHash->{$ReactionSet}}));
			for (my $j=0; $j < @{$AltList}; $j++) {
				my $CurrentNewSolutions;
				my $Index;
				if ($j == 0) {
					print RECONCILIATION "NEW SET\n";
				} elsif ($AltList->[$j] ne $ReactionSet) {
					print RECONCILIATION "ALTERNATIVE SET\n";
					#For each base solution in which this set is represented, we copy the base solution to the new solution
					my $NewSolutionCount = 0;
					for (my $k=0; $k < $SolutionCount; $k++) {
						if (defined($ReactionSetHash->{$ReactionSet}->{$AltList->[$j]}->{$k})) {
							if (defined($Solutions)) {
								$Index->{$k} = @{$Solutions} + $NewSolutionCount;
							} else {
								$Index->{$k} = $NewSolutionCount;
							}
							if (defined($NewSolutions) && @{$NewSolutions} > 0) {
								$Index->{$k} += @{$NewSolutions};
							}
							$CurrentNewSolutions->[$NewSolutionCount] = {};
							foreach my $Reaction (keys(%{$Solutions->[$k]})) {
								$CurrentNewSolutions->[$NewSolutionCount]->{$Reaction} = $Solutions->[$k]->{$Reaction};
							}
							$NewSolutionCount++;
						}
					}
				}
				if ($j == 0 || $AltList->[$j] ne $ReactionSet) {
					my @SingletReactions = split(/,/,$AltList->[$j]);
					for (my $i=0; $i < @SingletReactions; $i++) {
						#Adding base reactions to base solutions and set reactions the new solutions
						if ($j == 0) {
							push(@{$BaseReactions},$SingletReactions[$i]);
						} else {
							for (my $k=0; $k < @{$CurrentNewSolutions}; $k++) {
								$CurrentNewSolutions->[$k]->{$SingletReactions[$i]} = 1;
							}
						}
						#Getting reaction data and printing reaction in output file
						my $ReactionData;
						if (defined($ReactionDataHash->{$SingletReactions[$i]})) {
							$ReactionData = $ReactionDataHash->{$SingletReactions[$i]};
						} else {
							my $Direction = substr($SingletReactions[$i],0,1);
							if ($Direction eq "+") {
								$Direction = "=>";
							} else {
								$Direction = "<=";
							}
							my $Reaction = substr($SingletReactions[$i],1);
							$ReactionData = FIGMODELObject->load($self->figmodel()->config("reaction directory")->[0].$Reaction,"\t");
							$ReactionData->{"DIRECTIONS"}->[0] = $Direction;
							$ReactionData->{"REACTIONS"}->[0] = $Reaction;
							if (!defined($ReactionData->{"DEFINITION"}->[0])) {
								$ReactionData->{"DEFINITION"}->[0] = "UNKNOWN";
							}
							if (!defined($ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0])) {
								$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0] = "UNKNOWN";
							}
							if (!defined($ReactionData->{"DELTAG"}->[0])) {
								$ReactionData->{"DELTAG"}->[0] = "UNKNOWN";
							}
							$ReactionDataHash->{$SingletReactions[$i]} = $ReactionData;
						}
						print RECONCILIATION $ReactionData->{"REACTIONS"}->[0].";".$ReactionData->{"DEFINITION"}->[0].";".$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0].";".$ReactionData->{"DELTAG"}->[0].";".$ReactionData->{"DIRECTIONS"}->[0].";".$ReactionSetHash->{$ReactionSet}->{$AltList->[$j]}->{"COUNT"};
						for (my $k=0; $k < $SolutionCount; $k++) {
							print RECONCILIATION ";";
							if (defined($ReactionSetHash->{$ReactionSet}->{$AltList->[$j]}->{$k})) {
								if ($j == 0) {
									print RECONCILIATION "|".$k."|";
								} else {
									print RECONCILIATION "|".$Index->{$k}."|";
								}
							}
						}
						print RECONCILIATION "\n";
					}
					#Adding the current new solutions to the new solutions array
					if (defined($CurrentNewSolutions) && @{$CurrentNewSolutions} > 0) {
						push(@{$NewSolutions},@{$CurrentNewSolutions});
					}
				}
			}
			#Adding the base reactions to all existing solutions
			for (my $j=0; $j < @{$Solutions}; $j++) {
				if (defined($ReactionSetHash->{$ReactionSet}->{$ReactionSet}->{$Solutions->[$j]->{"BASE"}})) {
					foreach my $SingleReaction (@{$BaseReactions}) {
						$Solutions->[$j]->{$SingleReaction} = 1;
					}
				}
			}
			#Adding the new solutions to the set of existing solutions
			push(@{$Solutions},@{$NewSolutions});
		}
		close(RECONCILIATION);
		#Now printing a file that defines all of the solutions in a format the testsolutions function understands
		open (RECONCILIATION, ">$OutputFilenameTwo");
		print RECONCILIATION "Experiment;Solution index;Solution cost;Solution reactions\n";
		for (my $i=0; $i < @{$Solutions}; $i++) {
			delete($Solutions->[$i]->{"BASE"});
			print RECONCILIATION "SR".$i.";".$i.";10;".join(",",keys(%{$Solutions->[$i]}))."\n";
		}
		close(RECONCILIATION);

		$GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		$Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECON TESTING TIMING"}->[0] = time()."-";
		$Row->{"GF RECON SOLUTIONS"}->[0] = @{$Solutions};
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");

		#Scheduling the solution testing
		if ($GapFill == 1) {
			system($self->figmodel()->config("scheduler executable")->[0]." \"add:testsolutions?".$self->id().$self->selected_version()."?-1?GFSR:BACK:fast:QSUB\"");
		} else {
			system($self->figmodel()->config("scheduler executable")->[0]." \"add:testsolutions?".$self->id().$self->selected_version()."?-1?GGSR:BACK:fast:QSUB\"");
		}
	} else {
		#Reading in the solution testing results
		my $Data;
		if ($GapFill == 1) {
			$Data = $self->figmodel()->database()->load_single_column_file($self->directory().$self->id().$self->selected_version()."-GFSREM.txt","");
		} else {
			$Data = $self->figmodel()->database()->load_single_column_file($self->directory().$self->id().$self->selected_version()."-GGSREM.txt","");
		}

		#Reading in the preliminate reconciliation report
		my $OutputData = $self->figmodel()->database()->load_single_column_file($OutputFilename,"");
		#Replacing the file tags with actual performance data
		my $Count = 0;
		for (my $i=0; $i < @{$Data}; $i++) {
			if ($Data->[$i] =~ m/^SR(\d+);.+;(\d+\/\d+);/) {
				my $Index = $1;
				my $Performance = $Index."/".$2;
				for (my $j=0; $j < @{$OutputData}; $j++) {
					$OutputData->[$j] =~ s/\|$Index\|/$Performance/g;
				}
			}
		}
		$self->figmodel()->database()->print_array_to_file($OutputFilename,$OutputData);

		my $GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		my $Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECON TESTING TIMING"}->[0] .= time();
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");
	}

	return 1;
}

=head3 DetermineCofactorLipidCellWallComponents
Definition:
	{cofactor=>{string:compound id=>float:coefficient},lipid=>...cellWall=>} = FIGMODELmodel->DetermineCofactorLipidCellWallComponents();
Description:
=cut
sub DetermineCofactorLipidCellWallComponents {
	my ($self) = @_;
	my $templateResults;
	my $genomestats = $self->genomeObj()->genome_stats();
	my $Class = $self->ppo()->cellwalltype();
	my $Name = $self->name();
	my $translation = {COFACTOR=>"cofactor",LIPIDS=>"lipid","CELL WALL"=>"cellWall"};
	#Checking for phoenix variants
	my $PhoenixVariantTable = $self->figmodel()->database()->get_table("Phoenix variants table");
	my $Phoenix = 0;
	my @Rows = $PhoenixVariantTable->get_rows_by_key($self->genome(),"GENOME");
	my $VariantHash;
	for (my $i=0; $i < @Rows; $i++) {
		$Phoenix = 1;
		if (defined($Rows[$i]->{"SUBSYSTEM"}) && defined($Rows[$i]->{"VARIANT"})) {
			$VariantHash->{$Rows[$i]->{"SUBSYSTEM"}->[0]} = $Rows[$i]->{"VARIANT"}->[0];
		}
	}
	#Collecting genome data
	my $RoleHash;
	my $FeatureTable = $self->figmodel()->GetGenomeFeatureTable($self->genome());
	for (my $i=0; $i < $FeatureTable->size(); $i++) {
		if (defined($FeatureTable->get_row($i)->{"ROLES"})) {
			for (my $j=0; $j < @{$FeatureTable->get_row($i)->{"ROLES"}}; $j++) {
				$RoleHash->{$FeatureTable->get_row($i)->{"ROLES"}->[$j]} = 1;
			}
		}
	}
	my $ssHash = $self->genomeObj()->active_subsystems();
	my @ssList = keys(%{$ssHash});
	for (my $i=0; $i < @ssList; $i++) {
		if (!defined($VariantHash->{$ssList[$i]})) {
			$VariantHash->{$ssList[$i]} = 1;
		}
	}
	#Scanning through the template item by item and determinine which biomass components should be added
	my $includedHash;
	my $BiomassReactionTemplateTable = $self->figmodel()->database()->get_table("BIOMASSTEMPLATE");
	for (my $i=0; $i < $BiomassReactionTemplateTable->size(); $i++) {
		my $Row = $BiomassReactionTemplateTable->get_row($i); 
		if (defined($translation->{$Row->{CLASS}->[0]})) {
			my $coef = -1;
			if ($Row->{"REACTANT"}->[0] eq "NO") {
				$coef = 1;
				if ($Row->{"COEFFICIENT"}->[0] =~ m/cpd/) {
					$coef = $Row->{"COEFFICIENT"}->[0];
				}
			}
			if (defined($Row->{"INCLUSION CRITERIA"}->[0]) && $Row->{"INCLUSION CRITERIA"}->[0] eq "UNIVERSAL") {
				$includedHash->{$Row->{"ID"}->[0]} = 1;
				$templateResults->{$translation->{$Row->{CLASS}->[0]}}->{$Row->{"ID"}->[0]} = $coef;
			} elsif (defined($Row->{"INCLUSION CRITERIA"}->[0])) {
				my $Criteria = $Row->{"INCLUSION CRITERIA"}->[0];
				my $End = 0;
				while ($End == 0) {
					if ($Criteria =~ m/^(.+)(AND)\{([^{^}]+)\}(.+)$/ || $Criteria =~ m/^(AND)\{([^{^}]+)\}$/ || $Criteria =~ m/^(.+)(OR)\{([^{^}]+)\}(.+)$/ || $Criteria =~ m/^(OR)\{([^{^}]+)\}$/) {
						print $Criteria." : ";
						my $Start = "";
						my $End = "";
						my $Condition = $1;
						my $Data = $2;
						if ($1 ne "AND" && $1 ne "OR") {
							$Start = $1;
							$End = $4;
							$Condition = $2;
							$Data = $3;
						}
						my $Result = "YES";
						if ($Condition eq "OR") {
							$Result = "NO";
						}
						my @Array = split(/\|/,$Data);
						for (my $j=0; $j < @Array; $j++) {
							if ($Array[$j] eq "YES" && $Condition eq "OR") {
								$Result = "YES";
								last;
							} elsif ($Array[$j] eq "NO" && $Condition eq "AND") {
								$Result = "NO";
								last;
							} elsif ($Array[$j] =~ m/^COMPOUND:(.+)/) {
								if (defined($includedHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (!defined($includedHash->{$1}) && $Condition eq "AND") {							
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!COMPOUND:(.+)/) {
								if (!defined($includedHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($includedHash->{$1}) && $Condition eq "AND") {							
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^NAME:(.+)/) {
								my $Comparison = $1;
								if ((!defined($Comparison) || !defined($Name) || $Name =~ m/$Comparison/) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($Comparison) && defined($Name) && $Name !~ m/$Comparison/ && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!NAME:(.+)/) {
								my $Comparison = $1;
								if ((!defined($Comparison) || !defined($Name) || $Name !~ m/$Comparison/) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($Comparison) && defined($Name) && $Name =~ m/$Comparison/ && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^SUBSYSTEM:(.+)/) {
								my @SubsystemArray = split(/`/,$1);
								if (@SubsystemArray == 1) {
									if (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} ne -1 && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif ((!defined($VariantHash->{$SubsystemArray[0]}) || $VariantHash->{$SubsystemArray[0]} eq -1) && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								} else {
									my $Match = 0;
									for (my $k=1; $k < @SubsystemArray; $k++) {
										if (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} eq $SubsystemArray[$k]) {
											$Match = 1;
											last;
										}
									}
									if ($Match == 1 && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif ($Match != 1 && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								}
							} elsif ($Array[$j] =~ m/^!SUBSYSTEM:(.+)/) {
								my @SubsystemArray = split(/`/,$1);
								if (@SubsystemArray == 1) {
									if ((!defined($VariantHash->{$SubsystemArray[0]}) || $VariantHash->{$SubsystemArray[0]} eq -1) && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} ne -1 && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								} else {
									my $Match = 0;
									for (my $k=1; $k < @SubsystemArray; $k++) {
										if (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} eq $SubsystemArray[$k]) {
											$Match = 1;
											last;
										}
									}
									if ($Match != 1 && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif ($Match == 1 && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								}
							} elsif ($Array[$j] =~ m/^ROLE:(.+)/) {
								if (defined($RoleHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (!defined($RoleHash->{$1}) && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!ROLE:(.+)/) {
								if (!defined($RoleHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($RoleHash->{$1}) && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^CLASS:(.+)/) {
								if ($Class eq $1 && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif ($Class ne $1 && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!CLASS:(.+)/) {
								if ($Class ne $1 && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif ($Class eq $1 && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							}
						}
						$Criteria = $Start.$Result.$End;
						print $Criteria."\n";
					} else {
						$End = 1;
						last;
					}
				}
				if ($Criteria eq "YES") {
					$templateResults->{$translation->{$Row->{CLASS}->[0]}}->{$Row->{"ID"}->[0]} = $coef;
					$includedHash->{$Row->{"ID"}->[0]} = 1;
				}
			}
		}
	}
	my $types = ["cofactor","lipid","cellWall"];
	my $cpdMgr = $self->figmodel()->database()->get_object_manager("compound");
	for (my $i=0; $i < @{$types}; $i++) {
		my @list =	keys(%{$templateResults->{$types->[$i]}});
		my $entries = 0;
		for (my $j=0; $j < @list; $j++) {
			if ($templateResults->{$types->[$i]}->{$list[$j]} eq "-1") {
				my $objs = $cpdMgr->get_objects({id=>$list[$j]});
				if (!defined($objs->[0]) || $objs->[0]->mass() == 0) {
					$templateResults->{$types->[$i]}->{$list[$j]} = -1e-5;
				} else {
					$entries++;
				}
			}
		}
		for (my $j=0; $j < @list; $j++) {
			if ($templateResults->{$types->[$i]}->{$list[$j]} eq "-1") {
				$templateResults->{$types->[$i]}->{$list[$j]} = -1/$entries;
			} elsif ($templateResults->{$types->[$i]}->{$list[$j]} =~ m/cpd/) {
				my $netCoef = 0;
				my @allcpd = split(/,/,$templateResults->{$types->[$i]}->{$list[$j]});
				for (my $k=0; $k < @allcpd; $k++) {
					if (defined($templateResults->{$types->[$i]}->{$allcpd[$k]}) && $templateResults->{$types->[$i]}->{$allcpd[$k]} ne "-1e-5") {
						$netCoef += (1/$entries);
					} elsif (defined($templateResults->{$types->[$i]}->{$allcpd[$k]}) && $templateResults->{$types->[$i]}->{$allcpd[$k]} eq "-1e-5") {
						$netCoef += 1e-5;
					}
				}
				$templateResults->{$types->[$i]}->{$list[$j]} = $netCoef;
			}
		}
	}
	return $templateResults;
}

=head3 BuildSpecificBiomassReaction
Definition:
	FIGMODELmodel->BuildSpecificBiomassReaction();
Description:
=cut
sub BuildSpecificBiomassReaction {
	my ($self) = @_;
	#Checking if the current biomass reaction appears in more than on model, if not, this biomass reaction is conserved for this model
	my $biomassID = $self->biomassReaction();
	if ($biomassID =~ m/bio\d\d\d\d\d/) {
		my $mdlObs = $self->figmodel()->database()->get_objects("model",{
			biomassReaction=>$biomassID
		});
		if (defined($mdlObs->[1])) {
			$biomassID = "NONE";
		}
	}
	#If the biomass ID is "NONE", then we create a new biomass reaction for the model
	my $bioObj;
	my $originalPackages = "";
	my $originalEssReactions = "";
	if ($biomassID !~ m/bio\d\d\d\d\d/) {
		#Getting the current largest ID
		$biomassID = $self->figmodel()->database()->check_out_new_id("bof");
		$bioObj = $self->figmodel()->database()->create_object("bof",{
			id=>$biomassID,owner=>$self->owner(),name=>"Biomass",equation=>"NONE",protein=>"0",
			energy=>"0",DNA=>"0",RNA=>"0",lipid=>"0",cellWall=>"0",cofactor=>"0",
			modificationDate=>time(),creationDate=>time(),
			cofactorPackage=>"NONE",lipidPackage=>"NONE",cellWallPackage=>"NONE",
			DNACoef=>"NONE",RNACoef=>"NONE",proteinCoef=>"NONE",lipidCoef=>"NONE",
			cellWallCoef=>"NONE",cofactorCoef=>"NONE",essentialRxn=>"NONE"
		});
		if (!defined($bioObj)) {
			return $self->error_message({function => "BuildSpecificBiomassReaction",message => "Could not create new biomass reaction ".$biomassID});
		}
	} else {
		#Getting the biomass DB handler from the database
		my $objs = $self->figmodel()->database()->get_objects("bof",{id=>$biomassID});
		if (!defined($objs->[0])) {
			return $self->error_message({function => "BuildSpecificBiomassReaction",message => "Could not find biomass reaction ".$biomassID." in database!"});
		}
		$bioObj = $objs->[0];
		$bioObj->owner($self->owner());
		if (defined($bioObj->essentialRxn())) {
			$originalEssReactions = $bioObj->essentialRxn();
			$originalPackages = $bioObj->cofactorPackage().$bioObj->lipidPackage().$bioObj->cellWallPackage();
		}
	}
	#Getting genome stats
	my $genomestats = $self->genomeObj()->genome_stats();
	my $Class = $self->ppo()->cellwalltype();
	#Setting global coefficients based on cell wall type
	my $biomassCompounds;
	my $compounds;
	if ($Class eq "Gram positive") {
		$compounds->{RNA} = {cpd00002=>-0.262,cpd00012=>1,cpd00038=>-0.323,cpd00052=>-0.199,cpd00062=>-0.215};
		$compounds->{protein} = {cpd00001=>1,cpd00023=>-0.0637,cpd00033=>-0.0999,cpd00035=>-0.0653,cpd00039=>-0.0790,cpd00041=>-0.0362,cpd00051=>-0.0472,cpd00053=>-0.0637,cpd00054=>-0.0529,cpd00060=>-0.0277,cpd00065=>-0.0133,cpd00066=>-0.0430,cpd00069=>-0.0271,cpd00084=>-0.0139,cpd00107=>-0.0848,cpd00119=>-0.0200,cpd00129=>-0.0393,cpd00132=>-0.0362,cpd00156=>-0.0751,cpd00161=>-0.0456,cpd00322=>-0.0660};
		$bioObj->protein("0.5284");
		$bioObj->DNA("0.026");
		$bioObj->RNA("0.0655");
		$bioObj->lipid("0.075");
		$bioObj->cellWall("0.25");
		$bioObj->cofactor("0.10");
	} else {
		$compounds->{RNA} = {cpd00002=>-0.262,cpd00012=>1,cpd00038=>-0.322,cpd00052=>-0.2,cpd00062=>-0.216};
		$compounds->{protein} = {cpd00001=>1,cpd00023=>-0.0492,cpd00033=>-0.1145,cpd00035=>-0.0961,cpd00039=>-0.0641,cpd00041=>-0.0451,cpd00051=>-0.0554,cpd00053=>-0.0492,cpd00054=>-0.0403,cpd00060=>-0.0287,cpd00065=>-0.0106,cpd00066=>-0.0347,cpd00069=>-0.0258,cpd00084=>-0.0171,cpd00107=>-0.0843,cpd00119=>-0.0178,cpd00129=>-0.0414,cpd00132=>-0.0451,cpd00156=>-0.0791,cpd00161=>-0.0474,cpd00322=>-0.0543};
		$bioObj->protein("0.563");
		$bioObj->DNA("0.031");
		$bioObj->RNA("0.21");
		$bioObj->lipid("0.093");
		$bioObj->cellWall("0.177");
		$bioObj->cofactor("0.039");
	}
	#Setting energy coefficient for all reactions
	$bioObj->energy("40");
	$compounds->{energy} = {cpd00002=>-1,cpd00001=>-1,cpd00008=>1,cpd00009=>1,cpd00067=>1};
	#Setting DNA coefficients based on GC content
	my $gc = $self->genomeObj()->ppo()->gcContent();
	$compounds->{DNA} = {cpd00012=>1,cpd00115=>0.5*(1-$gc),cpd00241=>0.5*$gc,cpd00356=>0.5*$gc,cpd00357=>0.5*(1-$gc)};
	#Setting Lipid,cell wall,and cofactor coefficients based on biomass template
	my $templateResults = $self->DetermineCofactorLipidCellWallComponents();
	$compounds->{cofactor} = $templateResults->{cofactor};
	$compounds->{lipid} = $templateResults->{lipid};
	$compounds->{cellWall} = $templateResults->{cellWall};
	#Getting package number for cofactor, lipid, and cell wall
	my $packages;
	my $packageTypes = ["Cofactor","Lipid","CellWall"];
	my $translation = {"Cofactor"=>"cofactor","Lipid"=>"lipid","CellWall"=>"cellWall"};
	for (my $i=0; $i < @{$packageTypes}; $i++) {
		my @cpdList = keys(%{$compounds->{$translation->{$packageTypes->[$i]}}});
		my $function = $translation->{$packageTypes->[$i]}."Package";
		if (@cpdList == 0) {
			$bioObj->$function("NONE");
		} else {
			my $cpdgrpObs = $self->figmodel()->database()->get_objects("cpdgrp",{type=>$packageTypes->[$i]."Package"});
			for (my $j=0; $j < @{$cpdgrpObs}; $j++) {
				$packages->{$packageTypes->[$i]}->{$cpdgrpObs->[$j]->grouping()}->{$cpdgrpObs->[$j]->COMPOUND()} = 1;
			}
			my @packageList = keys(%{$packages->{$packageTypes->[$i]}});
			my $packageHash;
			for (my $j=0; $j < @packageList; $j++) {
				$packageHash->{join("|",sort(keys(%{$packages->{$packageTypes->[$i]}->{$packageList[$j]}})))} = $packageList[$j];
			}
			if (defined($packageHash->{join("|",sort(keys(%{$compounds->{$translation->{$packageTypes->[$i]}}})))})) {
				$bioObj->$function($packageHash->{join("|",sort(keys(%{$compounds->{$translation->{$packageTypes->[$i]}}})))});
			} else {
				my $newPackageID = $self->figmodel()->database()->check_out_new_id($packageTypes->[$i]."Package");
				$bioObj->$function($newPackageID);
				my @cpdList = keys(%{$compounds->{$translation->{$packageTypes->[$i]}}});
				for (my $j=0; $j < @cpdList; $j++) {
					$self->figmodel()->database()->create_object("cpdgrp",{
						COMPOUND=>$cpdList[$j],
						grouping=>$newPackageID,
						type=>$packageTypes->[$i]."Package"
					});	
				}
			}
		}
	}
	#Filling in coefficient terms in database and calculating global reaction coefficients based on classification abundancies
	my $equationCompounds;
	my $types = ["RNA","DNA","protein","lipid","cellWall","cofactor","energy"];
	for (my $i=0; $i < @{$types}; $i++) {
		my $coefString = "";
		my @compounds = sort(keys(%{$compounds->{$types->[$i]}}));
		#Building coefficient strings and determining net mass for component types
		my $netMass = 0;
		for (my $j=0; $j < @compounds; $j++) {		
			my $objs = $self->figmodel()->database()->get_objects("compound",{id=>$compounds[$j]});
			my $mass = 0;
			if (defined($objs->[0]) && $objs->[0]->mass() != 0) {
				$mass = $objs->[0]->mass();
				$netMass += -$compounds->{$types->[$i]}->{$compounds[$j]}*$objs->[0]->mass();
			}
			if (!defined($equationCompounds->{$compounds[$j]})) {
				$equationCompounds->{$compounds[$j]}->{"coef"} = 0;
				$equationCompounds->{$compounds[$j]}->{"type"} = $types->[$i];
				$equationCompounds->{$compounds[$j]}->{"mass"} = $mass;
			}
			$coefString .= $compounds->{$types->[$i]}->{$compounds[$j]}."|";
		}
		$netMass = 0.001*$netMass;
		#Calculating coefficients for all component compounds
		for (my $j=0; $j < @compounds; $j++) {
			#Normalizing certain type coefficients by mass
			my $function = $types->[$i];
			my $fraction = $bioObj->$function();
			if ($types->[$i] ne "energy") {
				$fraction = $fraction/$netMass;
			}
			if ($compounds->{$types->[$i]}->{$compounds[$j]} eq 1e-5) {
				$fraction = 1;	
			}
			$equationCompounds->{$compounds[$j]}->{"coef"} += $fraction*$compounds->{$types->[$i]}->{$compounds[$j]};
		}
		chop($coefString);
		if (length($coefString) == 0) {
			$coefString = "NONE";
		}
		my $function = $types->[$i]."Coef";
		if ($types->[$i] ne "energy") {
			$bioObj->$function($coefString);
		}
	}
	#Adding biomass to compound list
	$equationCompounds->{cpd17041}->{coef} = -1;
	$equationCompounds->{cpd17041}->{type} = "macromolecule";
	$equationCompounds->{cpd17042}->{coef} = -1;
	$equationCompounds->{cpd17042}->{type} = "macromolecule";
	$equationCompounds->{cpd17043}->{coef} = -1;
	$equationCompounds->{cpd17043}->{type} = "macromolecule";
	$equationCompounds->{cpd11416}->{coef} = 1;
	$equationCompounds->{cpd11416}->{type} = "macromolecule";
	#Building equation from hash and populating compound biomass table
	my @compoundList = keys(%{$equationCompounds});
	my ($reactants,$products);
	#Deleting existing Biomass Compound info
	my $matchingObjs = $self->figmodel()->database()->get_objects("cpdbof",{BIOMASS=>$biomassID});
	for (my $i=0; $i < @{$matchingObjs}; $i++) {
		$matchingObjs->[$i]->delete();
	}
	my $typeCategories = {"macromolecule"=>"M","RNA"=>"R","DNA"=>"D","protein"=>"P","lipid"=>"L","cellWall"=>"W","cofactor"=>"C","energy"=>"E"};
	my $productmass = 0;
	my $reactantmass = 0;
	my $totalmass = 0;
	foreach my $compound (@compoundList) {
		if (defined($equationCompounds->{$compound}->{coef}) && defined($equationCompounds->{$compound}->{mass})) {
			$totalmass += $equationCompounds->{$compound}->{coef}*0.001*$equationCompounds->{$compound}->{mass};
		}
		if ($equationCompounds->{$compound}->{coef} < 0) {
			if (defined($equationCompounds->{$compound}->{coef}) && defined($equationCompounds->{$compound}->{mass})) {
				$reactantmass += $equationCompounds->{$compound}->{coef}*0.001*$equationCompounds->{$compound}->{mass};
			}
			$reactants->{$compound} = $self->figmodel()->format_coefficient(-1*$equationCompounds->{$compound}->{coef});
		} else {
			if (defined($equationCompounds->{$compound}->{coef}) && defined($equationCompounds->{$compound}->{mass})) {
				$productmass += $equationCompounds->{$compound}->{coef}*0.001*$equationCompounds->{$compound}->{mass};
			}
			$products->{$compound} = $self->figmodel()->format_coefficient($equationCompounds->{$compound}->{coef});
		}
		#Adding biomass reaction compounds to the biomass compound table
		$self->figmodel()->database()->create_object("cpdbof",{
			COMPOUND=>$compound,
			BIOMASS=>$biomassID,
			coefficient=>$equationCompounds->{$compound}->{coef},
			compartment=>"c",
			category=>$typeCategories->{$equationCompounds->{$compound}->{type}}
		});
	}
	print "Total mass = ".$totalmass.", Reactant mass = ".$reactantmass.", Product mass = ".$productmass."\n";
	my $Equation = "";
	my @ReactantList = sort(keys(%{$reactants}));
	for (my $i=0; $i < @ReactantList; $i++) {
		if (length($Equation) > 0) {
			$Equation .= " + ";
		}
		$Equation .= "(".$reactants->{$ReactantList[$i]}.") ".$ReactantList[$i];
	}
	$Equation .= " => ";
	my $First = 1;
	@ReactantList = sort(keys(%{$products}));
	for (my $i=0; $i < @ReactantList; $i++) {
		if ($First == 0) {
			$Equation .= " + ";
		}
		$First = 0;
		$Equation .= "(".$products->{$ReactantList[$i]}.") ".$ReactantList[$i];
	}
	$bioObj->equation($Equation);
	#Setting the biomass reaction of this model
	$self->biomassReaction($biomassID);
	$self->figmodel()->print_biomass_reaction_file($biomassID);
	#Checking if the biomass reaction remained unchanged
	if ($originalPackages ne "" && $originalPackages eq $bioObj->cofactorPackage().$bioObj->lipidPackage().$bioObj->cellWallPackage()) {
		print "UNCHANGED!\n";
		$bioObj->essentialRxn($originalEssReactions);
	} else {
		#Copying essential reaction lists if the packages in this biomasses reaction exactly match those in another biomass reaction
		my $matches = $self->figmodel()->database()->get_objects("bof",{
			cofactorPackage=>$bioObj->cofactorPackage(),
			lipidPackage=>$bioObj->lipidPackage(),
			cellWallPackage=>$bioObj->cellWallPackage()
		});
		my $matchFound = 0;
		for (my $i=0; $i < @{$matches}; $i++) {
			if ($matches->[$i]->id() ne $biomassID && defined($matches->[$i]->essentialRxn()) && length($matches->[$i]->essentialRxn())) {
				$bioObj->essentialRxn($matches->[$i]->essentialRxn());
				print "MATCH!\n";
				$matchFound = 1;
				last;
			}
		}
		#Otherwise, we calculate essential reactions
		if ($matchFound == 0) {
			print "NOMATCH!\n";
			$self->figmodel()->add_job_to_queue({
				command => "runfigmodelfunction?determine_biomass_essential_reactions?".$biomassID,
				user => $self->owner(),
				queue => "fast"
			});
		}
	}
	return $biomassID;
}

=head3 PrintSBMLFile
Definition:
	FIGMODELmodel->PrintSBMLFile();
Description:
	Printing file with model data in SBML format
=cut
sub PrintSBMLFile {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{print => 1});
	if (defined($args->{error})) {return $self->error_message({function => "PrintSBMLFile",args => $args});}
	if (-e $self->directory().$self->id().".xml") {
		unlink($self->directory().$self->id().".xml");	
	}
	#Adding intracellular metabolites that also need exchange fluxes to the exchange hash
	my $ExchangeHash = {"cpd11416" => "c"};
	my %CompartmentsPresent;
	$CompartmentsPresent{"c"} = 1;
	my %CompoundList;
	my @ReactionList;
	my $rxnDBHash = $self->figmodel()->database()->get_object_hash({
		type => "reaction",
		attribute => "id",
		useCache => 1
	});
	my $rxnmdl = $self->rxnmdl();
	my $rxnHash;
	my $reactionCompartments;
	for (my $i=0; $i < @{$rxnmdl}; $i++) {
		$rxnHash->{$rxnmdl->[$i]->REACTION()}->{$rxnmdl->[$i]->compartment()} = $rxnmdl->[$i];
		my $rxnObj;
		if ($rxnmdl->[$i]->REACTION() =~ m/rxn\d\d\d\d\d/) {
			if (defined($rxnDBHash->{$rxnmdl->[$i]->REACTION()})) {
				$rxnObj = $rxnDBHash->{$rxnmdl->[$i]->REACTION()}->[0];
			}
		} elsif ($rxnmdl->[$i]->REACTION() =~ m/bio\d\d\d\d\d/) {
			$rxnObj = $self->figmodel()->database()->get_object("bof",{id=>$rxnmdl->[$i]->REACTION()});	
		}
		if (!defined($rxnObj)) {
			next;	
		}
		push(@{$reactionCompartments},$rxnmdl->[$i]->compartment());
		push(@ReactionList,$rxnObj);
		$_ = $rxnObj->equation();
		my @MatchArray = /(cpd\d\d\d\d\d)/g;
		for (my $j=0; $j < @MatchArray; $j++) {
			$CompoundList{$MatchArray[$j]}->{"c"} = 1;
		}
		$_ = $rxnObj->equation();
		@MatchArray = /(cpd\d\d\d\d\d\[\D\])/g;
		for (my $j=0; $j < @MatchArray; $j++) {
			if ($MatchArray[$j] =~ m/(cpd\d\d\d\d\d)\[(\D)\]/) {
				$CompartmentsPresent{lc($2)} = 1;
				$CompoundList{$1}->{lc($2)} = 1;
			}
		}
	}

	#Printing header to SBML file
	my $ModelName = $self->fullId();
	$ModelName =~ s/\./_/g;
	my $output;
	push(@{$output},'<?xml version="1.0" encoding="UTF-8"?>');
	push(@{$output},'<sbml xmlns="http://www.sbml.org/sbml/level2" level="2" version="1" xmlns:html="http://www.w3.org/1999/xhtml">');
	my $name = $self->name()." SEED model";
	$name =~ s/[\s\.]/_/g;
	push(@{$output},'<model id="'.$ModelName.'" name="'.$name.'">');

	#Printing the unit data
	push(@{$output},"<listOfUnitDefinitions>");
	push(@{$output},"\t<unitDefinition id=\"mmol_per_gDW_per_hr\">");
	push(@{$output},"\t\t<listOfUnits>");
	push(@{$output},"\t\t\t<unit kind=\"mole\" scale=\"-3\"/>");
	push(@{$output},"\t\t\t<unit kind=\"gram\" exponent=\"-1\"/>");
	push(@{$output},"\t\t\t<unit kind=\"second\" multiplier=\".00027777\" exponent=\"-1\"/>");
	push(@{$output},"\t\t</listOfUnits>");
	push(@{$output},"\t</unitDefinition>");
	push(@{$output},"</listOfUnitDefinitions>");

	#Printing compartments for SBML file
	push(@{$output},'<listOfCompartments>');
	foreach my $Compartment (keys(%CompartmentsPresent)) {
		my $cmpObj = $self->figmodel()->database()->get_object("compartment",{id => $Compartment});
		if (!defined($cmpObj)) {
			next;
		}
		my @OutsideList = split(/\//,$cmpObj->outside());
		my $Printed = 0;
		foreach my $Outside (@OutsideList) {
			if (defined($CompartmentsPresent{$Outside})) {
				my $newObj = $self->figmodel()->database()->get_object("compartment",{id => $Outside});
				if (defined($newObj)) {
					push(@{$output},'<compartment id="'.$cmpObj->name().'" outside="'.$newObj->name().'"/>');
					$Printed = 1;
					last;
				}
			}
		}
		if ($Printed eq 0) {
			push(@{$output},'<compartment id="'.$cmpObj->name().'"/>');
		}
	}
	push(@{$output},'</listOfCompartments>');

	#Printing the list of metabolites involved in the model
	push(@{$output},'<listOfSpecies>');
	my $cpdHash = $self->figmodel()->database()->get_object_hash({
		type => "compound",
		attribute => "id",
		useCache => 1
	});
	foreach my $Compound (keys(%CompoundList)) {
		my $cpdObj;
		if (defined($cpdHash->{$Compound})) {
			$cpdObj = $cpdHash->{$Compound}->[0];
		}
		if (!defined($cpdObj)) {
			next;	
		}
		my $Formula = "";
		if (defined($cpdObj->formula())) {
			$Formula = $cpdObj->formula();
		}
		my $Name = $cpdObj->name();
		$Name =~ s/\s/_/;
		$Name .= "_".$Formula;
		$Name =~ s/[<>;:&\*]//;
		my $Charge = 0;
		if (defined($cpdObj->charge())) {
			$Charge = $cpdObj->charge();
		}
		foreach my $Compartment (keys(%{$CompoundList{$Compound}})) {
			if ($Compartment eq "e") {
				$ExchangeHash->{$Compound} = "e";
			}
			my $cmpObj = $self->figmodel()->database()->get_object("compartment",{id => $Compartment});
			#print STDERR $Compartment,"\t",$cmpObj,"\t",$cmpObj->name(),"\n";
			push(@{$output},'<species id="'.$Compound.'_'.$Compartment.'" name="'.$Name.'" compartment="'.$cmpObj->name().'" charge="'.$Charge.'" boundaryCondition="false"/>');
		}
	}
	
	#Printing the boundary species
	foreach my $Compound (keys(%{$ExchangeHash})) {
		my $cpdObj;
		if (defined($cpdHash->{$Compound})) {
			$cpdObj = $cpdHash->{$Compound}->[0];
		}
		if (!defined($cpdObj)) {
			next;	
		}
		my $Formula = "";
		if (defined($cpdObj->formula())) {
			$Formula = $cpdObj->formula();
		}
		my $Name = $cpdObj->name();
		$Name =~ s/\s/_/;
		$Name .= "_".$Formula;
		$Name =~ s/[<>;:&\*]//;
		my $Charge = 0;
		if (defined($cpdObj->charge())) {
			$Charge = $cpdObj->charge();
		}
		push(@{$output},'<species id="'.$Compound.'_b" name="'.$Name.'" compartment="Extracellular" charge="'.$Charge.'" boundaryCondition="true"/>');
	}
	push(@{$output},'</listOfSpecies>');

	#Printing the list of reactions involved in the model
	my $ObjectiveCoef;
	push(@{$output},'<listOfReactions>');
	#TODO
	#my $mapTbl = $self->figmodel()->database()->get_table("KEGGMAPDATA");
	my $keggAliasHash = $self->figmodel()->database()->get_object_hash({
		type => "rxnals",
		attribute => "REACTION",
		parameters => {type=>"KEGG"},
		useCache => 1
	});
	for (my $i=0; $i < @ReactionList; $i++) {
	   	my $rxnObj = $ReactionList[$i];
		$ObjectiveCoef = "0.0";
		my $mdlObj = $rxnHash->{$rxnObj->id()}->{$reactionCompartments->[$i]};
		if ($rxnObj->id() =~ m/^bio/) {
			$ObjectiveCoef = "1.0";
		}
		my $LowerBound = -10000;
		my $UpperBound = 10000;
		my ($Reactants,$Products) = $self->figmodel()->get_reaction("rxn00001")->substrates_from_equation({equation=>$rxnObj->equation()});
		my $Name = $rxnObj->name();
		$Name =~ s/[<>;:&\*]//g;
		my $Reversibility = "true";
		if ($mdlObj->directionality() ne "<=>") {
			$LowerBound = 0;
			$Reversibility = "false";
		}
		if ($mdlObj->directionality() eq "<=") {
			my $Temp = $Products;
			$Products = $Reactants;
			$Reactants = $Temp;
		}
		 push(@{$output},'<reaction id="'.$rxnObj->id().'" name="'.$Name.'" reversible="'.$Reversibility.'">');
		 push(@{$output},"<notes>");
		my $ECData = "";
		if ($rxnObj->id() !~ m/^bio/) {
			if (defined($rxnObj->enzyme())) {
				my @ecList = split(/\|/,$rxnObj->enzyme());
				if (defined($ecList[1])) {
					$ECData = $ecList[1];
				}
			}
		}
		my $KEGGID = "";		
		if (defined($keggAliasHash->{$rxnObj->id()})) {
			$KEGGID = $keggAliasHash->{$rxnObj->id()}->[0]->alias();
		}
		my $KEGGMap = "";
		#TODO
		#my @rows = $mapTbl->get_rows_by_key($rxnObj->id(),"REACTIONS");
		#for (my $i=0; $i < @rows; $i++) {
		#	if ($i > 0) {
		#		$KEGGMap .= ";"
		#	}
		#	$KEGGMap .= $rows[$i]->{NAME}->[0];
		#}
		my $SubsystemData = "";
		my $GeneAssociation = "";
		my $ProteinAssociation = "";
		my $GeneLocus = "";
		my $GeneGI = "";
		my $pegs = $mdlObj->pegs();
		if (length($pegs) > 0 && $pegs ne "NONE") {
			$pegs =~ s/\+/  and  /g;
			$pegs =~ s/\|/ ) or ( /g;
			if ($pegs =~ m/\sor\s/ || $pegs =~ m/\sand\s/) {
				$pegs = "( ".$pegs." )";
			}
			$GeneAssociation = $pegs;
		}
		if (length($GeneAssociation) > 0) {
			push(@{$output},"<html:p>GENE_ASSOCIATION:".$GeneAssociation."</html:p>");
		}
		if (length($GeneLocus) > 0) {
			push(@{$output},"<html:p>GENE_LOCUS_TAG:".$GeneLocus."</html:p>");
		}
		if (length($GeneGI) > 0) {
			push(@{$output},"<html:p>GENE_GI:".$GeneGI."</html:p>");
		}
		if (length($ProteinAssociation) > 0) {
			push(@{$output},"<html:p>PROTEIN_ASSOCIATION:".$ProteinAssociation."</html:p>");
		}
		if (length($KEGGID) > 0) {
			push(@{$output},"<html:p>KEGG_RID:".$KEGGID."</html:p>");
		}
		if (length($KEGGMap) > 0) {
			push(@{$output},"<html:p>KEGG_MAP:".$KEGGMap."</html:p>");
		}
		if (length($SubsystemData) > 0 && $SubsystemData ne "NONE") {
			push(@{$output},"<html:p>SUBSYSTEM:".$SubsystemData."</html:p>");
		}
		if (length($ECData) > 0) {
			push(@{$output},"<html:p>PROTEIN_CLASS:".$ECData."</html:p>");
		}
		 push(@{$output},"</notes>");
		 if (defined($Reactants) && @{$Reactants} > 0) {
			 push(@{$output},"<listOfReactants>");
			 foreach my $Reactant (@{$Reactants}) {
				 push(@{$output},'<speciesReference species="'.$Reactant->{"DATABASE"}->[0]."_".$Reactant->{"COMPARTMENT"}->[0].'" stoichiometry="'.$Reactant->{"COEFFICIENT"}->[0].'"/>');
			 }
			 push(@{$output},"</listOfReactants>");
		 }
		 if (defined($Products) && @{$Products} > 0) {
			 push(@{$output},"<listOfProducts>");
			foreach my $Product (@{$Products}) {
				 push(@{$output},'<speciesReference species="'.$Product->{"DATABASE"}->[0]."_".$Product->{"COMPARTMENT"}->[0].'" stoichiometry="'.$Product->{"COEFFICIENT"}->[0].'"/>');
			 }
			push(@{$output},"</listOfProducts>");
		 }
		push(@{$output},"<kineticLaw>");
		push(@{$output},"\t<math xmlns=\"http://www.w3.org/1998/Math/MathML\">");
		push(@{$output},"\t\t\t<ci> FLUX_VALUE </ci>");
		push(@{$output},"\t</math>");
		push(@{$output},"\t<listOfParameters>");
		push(@{$output},"\t\t<parameter id=\"LOWER_BOUND\" value=\"".$LowerBound."\" units=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"UPPER_BOUND\" value=\"".$UpperBound."\" units=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"OBJECTIVE_COEFFICIENT\" value=\"".$ObjectiveCoef."\"/>");
		push(@{$output},"\t\t<parameter id=\"FLUX_VALUE\" value=\"0.0\" units=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t</listOfParameters>");
		push(@{$output},"</kineticLaw>");
		push(@{$output},'</reaction>');
	}

	my @ExchangeList = keys(%{$ExchangeHash});
	foreach my $ExCompound (@ExchangeList) {
		my $cpdObj;
		if (defined($cpdHash->{$ExCompound})) {
			$cpdObj = $cpdHash->{$ExCompound}->[0];
		}
		if (!defined($cpdObj)) {
			next;	
		}
		my $ExCompoundName = $cpdObj->name();
		$ExCompoundName =~ s/[<>;&]//g;
		$ObjectiveCoef = "0.0";
		push(@{$output},'<reaction id="EX_'.$ExCompound.'_'.$ExchangeHash->{$ExCompound}.'" name="EX_'.$ExCompoundName.'_'.$ExchangeHash->{$ExCompound}.'" reversible="true">');
		push(@{$output},"\t".'<notes>');
		push(@{$output},"\t\t".'<html:p>GENE_ASSOCIATION: </html:p>');
		push(@{$output},"\t\t".'<html:p>PROTEIN_ASSOCIATION: </html:p>');
		push(@{$output},"\t\t".'<html:p>SUBSYSTEM: S_</html:p>');
		push(@{$output},"\t\t".'<html:p>PROTEIN_CLASS: </html:p>');
		push(@{$output},"\t".'</notes>');
		push(@{$output},"\t".'<listOfReactants>');
		push(@{$output},"\t\t".'<speciesReference species="'.$ExCompound.'_'.$ExchangeHash->{$ExCompound}.'" stoichiometry="1.000000"/>');
		push(@{$output},"\t".'</listOfReactants>');
		push(@{$output},"\t".'<listOfProducts>');
		push(@{$output},"\t\t".'<speciesReference species="'.$ExCompound.'_b" stoichiometry="1.000000"/>');
		push(@{$output},"\t".'</listOfProducts>');
		push(@{$output},"\t".'<kineticLaw>');
		push(@{$output},"\t\t".'<math xmlns="http://www.w3.org/1998/Math/MathML">');
		push(@{$output},"\t\t\t\t".'<ci> FLUX_VALUE </ci>');
		push(@{$output},"\t\t".'</math>');
		push(@{$output},"\t\t".'<listOfParameters>');
		push(@{$output},"\t\t\t".'<parameter id="LOWER_BOUND" value="-10000.000000" units="mmol_per_gDW_per_hr"/>');
		push(@{$output},"\t\t\t".'<parameter id="UPPER_BOUND" value="10000.000000" units="mmol_per_gDW_per_hr"/>');
		push(@{$output},"\t\t\t".'<parameter id="OBJECTIVE_COEFFICIENT" value="'.$ObjectiveCoef.'"/>');
		push(@{$output},"\t\t\t".'<parameter id="FLUX_VALUE" value="0.000000" units="mmol_per_gDW_per_hr"/>');
		push(@{$output},"\t\t".'</listOfParameters>');
		push(@{$output},"\t".'</kineticLaw>');
		push(@{$output},'</reaction>');
	}

	#Closing out the file
	push(@{$output},'</listOfReactions>');
	push(@{$output},'</model>');
	push(@{$output},'</sbml>');
	if ($args->{print} == 1) {
		$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().".xml",$output);
	}
	return $output;
}
=head3 getSBMLFileReactions
Definition:
	Output:{} = FIGMODELmodel->getSBMLFileReactions({});
Description:
	Prints the table of model data
=cut
sub getSBMLFileReactions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	if (defined($args->{error})) {return $self->error_message({function => "generate_feature_data_table",args => $args});}
	my $data = $self->figmodel()->database()->load_single_column_file($self->directory().$self->id().".xml","");
	my $results;
	for (my $i=0; $i < @{$data}; $i++) {
		if ($data->[$i] =~ m/([rb][xi][no]\d\d\d\d\d)/) {
			$results->{SBMLreactons}->{$1} = 1;
		} elsif ($data->[$i] =~ m/(cpd\d\d\d\d\d)/) {
			$results->{SBMLcompounds}->{$1} = 1;
		}
	}
	my $rxnTbl = $self->reaction_table();
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		if (!defined($results->{SBMLreactons}->{$rxnTbl->get_row($i)->{LOAD}->[0]})) {
			$results->{missingReactons}->{$rxnTbl->get_row($i)->{LOAD}->[0]} = 1;
		}
	}
	my $cpdTbl = $self->compound_table();
	for (my $i=0; $i < $cpdTbl->size(); $i++) {
		if (!defined($results->{SBMLcompounds}->{$cpdTbl->get_row($i)->{DATABASE}->[0]})) {
			$results->{missingCompounds}->{$cpdTbl->get_row($i)->{DATABASE}->[0]} = 1;
		}
	}
	return $results;
}
=head3 publicTable
Definition:
	FIGMODELTable = FIGMODELmodel->publicTable({type => R/C/F});
Description:
	This function prints the form of the reaction,compound,and gene tables that are used when generating the excel file for the metabolic models
=cut
sub publicTable {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["type"],{});
	if (defined($args->{error})) {return $self->error_message({function => "publicTable",args => $args});}
	if ($args->{type} eq "R") {
		return $self->generate_reaction_data_table($args);
	} elsif ($args->{type} eq "C") {
		return $self->generate_compound_data_table($args);
	} elsif ($args->{type} eq "F") {
		   return $self->generate_feature_data_table($args);
	}
	return $self->error_message({message=>"Input type not recognized",function => "publicTable",args => $args});
}

=head3 rxnmdl
Definition:
	[PPO:rxnmdl] = FIGMODELmodel->rxnmdl({
		useCache => 1,
		clearCache => 0	
	});
Description:
	Returns a list of the PPO rxnmdl objects for the model
=cut
sub rxnmdl {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		useCache => 1,
		clearCache => 0
	});
	return [] if (defined($args->{error}));
	if ($args->{clearCache} == 1) {
		delete $self->{_rxnmdl};
	}
	if (defined($self->{_rxnmdl}) && $args->{useCache} == 1) {
		return $self->{_rxnmdl};	
	} else {
		$self->{_rxnmdl} = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL=>$self->id()});
	}
	return $self->{_rxnmdl};
}

=head3 rxnmdlHash
Definition:
	{string:reaction ID => [PPO:rxnmdl]} = FIGMODELmodel->rxnmdlHash({
		useCache => 1,
		clearCache => 0	
	});
Description:
	Returns a list of the PPO rxnmdl objects for the model
=cut
sub rxnmdlHash {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		useCache => 1,
		clearCache => 0
	});
	return {} if (defined($args->{error}));
	if ($args->{clearCache} == 1) {
		delete $self->{_rxnmdlHash};
	}
	if (defined($self->{_rxnmdlHash}) && $args->{useCache} == 1) {
		return $self->{_rxnmdlHash};	
	} else {
		my $rxnmdl = $self->rxnmdl($args);
		for (my $i=0; $i < @{$rxnmdl}; $i++) {
			push(@{$self->{_rxnmdlHash}->{$rxnmdl->[$i]->REACTION()}},$rxnmdl->[$i]);
		}
	}
	return $self->{_rxnmdlHash};
}

=head3 reaction_table
Definition:
	FIGMODELTable = FIGMODELmodel->reaction_table();
Description:
	Returns FIGMODELTable with the reaction list for the model
=cut
sub reaction_table {
	my ($self,$clear) = @_;
	if (defined($clear) && $clear == 1) {
		delete $self->{_reaction_table};
	}
	if (!defined($self->{_reaction_table})) {
		my $rxnmdls = $self->figmodel()->database()->get_objects("rxnmdl", { MODEL => $self->id() });
		my $table_config = {
			delimiter => ";",
			item_delimiter => "|",
			heading_remap => { 'REACTION' => 'LOAD',
							   'directionality' => 'DIRECTIONALITY',
							   'compartment' => 'COMPARTMENT',
							   'pegs' => 'ASSOCIATED PEG',
							   'confidence' => 'CONFIDENCE',
							   'reference' => 'REFERENCE',
							   'notes' => 'NOTES',
							   'subsystem' => 'SUBSYSTEM',
							 },
			};
		$self->{_reaction_table} = $self->figmodel()->database()->ppo_rows_to_table($table_config, $rxnmdls);
	}
	return $self->{_reaction_table};
}

=head3 generate_reaction_data_table
Definition:
	FIGMODELtable = FIGMODELmodel->generate_reaction_data_table({
		...
	});
Description:
	Creates a table of model reaction data
=cut
sub generate_reaction_data_table {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		-abbrev_eq => 0,
		-name_eq => 1,
		-id_eq => 1,
		-direction => 1,
		-compartment => 1,
		-pegs => 1,
		-roles => 0,
		-notes => 0,
		-kegg => 1,
		-deltaG => 1,
		-deltaGerr => 1,
		-name => 1,
		-EC => 1,
		-subsystem => 0,
		-reference => 0
	});
	if (defined($args->{error})) {return $self->error_message({function => "generate_reaction_data_table",args => $args});}
	my $headingArgHash = {
		EQUATION => "-id_eq",
		"ABBREVIATION EQ" => "-abbrev_eq",
		"NAME EQ" => "-name_eq",
		DIRECTION => "-direction",
		COMPARTMENT => "-compartment",
		ROLES => "-roles",
		PEGS => "-pegs",
		NOTES => "-notes",
		"KEGG ID(S)" => "-kegg",
		"DELTAG (kcal/mol)" => "-deltaG",
		"DELTAG ERROR (kcal/mol)" => "-deltaGerr",
		NAME => "-name",
		"EC NUMBER(S)" => "-ec",
		SUBSYSTEMS => "-subsystem",
		REFERENCE => "-reference"
	};
	my $headings = ["DATABASE"];
	#Temporarily removed these:"SUBSYSTEMS","NOTES","REFERECE"
	my $fullOrderedList = ["NAME","EC NUMBER(S)","KEGG ID(S)","DELTAG (kcal/mol)","DELTAG ERROR (kcal/mol)","EQUATION","ABBREVIATION EQ","NAME EQ","DIRECTION","COMPARTMENT","PEGS","ROLES"];
	foreach my $flag (@{$fullOrderedList}) {
		if (!defined($headingArgHash->{$flag}) || !defined($args->{$headingArgHash->{$flag}}) || $args->{$headingArgHash->{$flag}} == 1) {
			push(@{$headings},$flag);
		}
	}
	my $roleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
	my $keggHash = $self->figmodel()->database()->get_object_hash({type=>"rxnals",attribute=>"REACTION",parameters=>{type=>"KEGG"},useCache=>1});
	my $rxnHash = $self->figmodel()->database()->get_object_hash({type=>"reaction",attribute=>"id",useCache=>1});
	my $rxntbl = $self->reaction_table();
	my $outputTbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$self->directory()."ReactionTable-".$self->id().".tbl",undef,"\t","|",undef);	
	for (my $i=0; $i < $rxntbl->size();$i++) {
		my $newRow;
		my $row = $rxntbl->get_row($i);
		my $obj;
		if (defined($rxnHash->{$row->{LOAD}->[0]})) {
			$obj = $rxnHash->{$row->{LOAD}->[0]}->[0];
		}
		my $biomass = 0;
		if (!defined($obj)) {
			$biomass = 1;
			$obj = $self->figmodel()->database()->get_object("bof",{id => $row->{LOAD}->[0]});
		}
		if (defined($obj)) {
			for (my $j=0; $j < @{$headings}; $j++) {
				if ($headings->[$j] eq "DATABASE") {
					$newRow->{$headings->[$j]}->[0] = $row->{LOAD}->[0];
				} elsif ($headings->[$j] eq "DIRECTION") {
					$newRow->{$headings->[$j]}->[0] = $row->{DIRECTIONALITY}->[0];
				} elsif ($headings->[$j] eq "COMPARTMENT") {
					$newRow->{$headings->[$j]}->[0] = $row->{COMPARTMENT}->[0];
				} elsif ($headings->[$j] eq "ROLES") {
					push(@{$newRow->{$headings->[$j]}},keys(%{$roleHash->{$row->{LOAD}->[0]}}));
				} elsif ($headings->[$j] eq "PEGS") {
					$newRow->{$headings->[$j]} = $row->{"ASSOCIATED PEG"};
				} elsif ($headings->[$j] eq "NOTES") {
					$newRow->{$headings->[$j]} = $row->{NOTES};
				} elsif ($headings->[$j] eq "REFERENCE") {
					$newRow->{$headings->[$j]} = $row->{REFERENCE};	
				} elsif ($headings->[$j] eq "EQUATION") {
					$newRow->{$headings->[$j]}->[0] = $self->get_reaction_equation({-id=>$row->{LOAD}->[0],-style=>"ID"});
				} elsif ($headings->[$j] eq "ABBREVIATION EQ") {
					$newRow->{$headings->[$j]}->[0] = $self->get_reaction_equation({-id=>$row->{LOAD}->[0],-style=>"ABBREV"});
				} elsif ($headings->[$j] eq "NAME EQ") {
					$newRow->{$headings->[$j]}->[0] = $self->get_reaction_equation({-id=>$row->{LOAD}->[0],-style=>"NAME"});
				} elsif ($headings->[$j] eq "KEGG ID(S)" && defined($keggHash->{$obj->id()})) {
					for (my $k=0; $k < @{$keggHash->{$obj->id()}}; $k++) {
						push(@{$newRow->{$headings->[$j]}},$keggHash->{$obj->id()}->[$k]->alias());
					}
				} elsif ($headings->[$j] eq "NAME") {
					$newRow->{$headings->[$j]}->[0] = $obj->name();
				} elsif ($headings->[$j] eq "EC NUMBER(S)" && $biomass == 0 && length($obj->enzyme()) > 2) {
					push(@{$newRow->{$headings->[$j]}},split(/\|/,substr($obj->enzyme(),1,length($obj->enzyme())-2)));
				} elsif ($headings->[$j] eq "DELTAG (kcal/mol)" && $biomass == 0) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaG();
				} elsif ($headings->[$j] eq "DELTAG ERROR (kcal/mol)" && $biomass == 0) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaGErr();
				} elsif ($headings->[$j] eq "SUBSYSTEMS" && $biomass == 0) {
					#TODO
					$newRow->{$headings->[$j]}->[0] = "NONE";
				}
			}
			$outputTbl->add_row($newRow);
		}
	}
	return $outputTbl;
}
=head3 compound_table
Definition:
	FIGMODELTable = FIGMODELmodel->compound_table();
Description:
	Returns FIGMODELTable with the compound list for the model
=cut
sub compound_table {
	my ($self) = @_;
	if (!defined($self->{_compound_table})) {
		$self->{_compound_table} = $self->create_table_prototype("ModelCompounds");
		#Loading the model
		my $ModelTable = $self->reaction_table();
		#Checking that the tables were loaded
		if (!defined($ModelTable)) {
			return undef;
		}
		#Finding the biomass reaction
		for (my $i=0; $i < $ModelTable->size(); $i++) {
			my $ID = $ModelTable->get_row($i)->{"LOAD"}->[0];
			my $obj = $self->figmodel()->database()->get_object("reaction",{id => $ID});
			my $IsBiomass = 0;
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->get_object("bof",{id => $ID});
				$IsBiomass = 1;
			}
			if (defined($obj)) {
				if (defined($obj->equation())) {
					$_ = $obj->equation();
					my @OriginalArray = /(cpd\d\d\d\d\d[\[\w]*)/g;
					foreach my $Compound (@OriginalArray) {
						my $cpdID = substr($Compound,0,8);
						my $NewRow = $self->{_compound_table}->get_row_by_key($cpdID,"DATABASE",1);
						if ($IsBiomass == 1) {
							$self->{_compound_table}->add_data($NewRow,"BIOMASS",$ID,1);
						}
						if (length($Compound) > 8) {
							my $Compartment = substr($Compound,9,1);
							$self->{_compound_table}->add_data($NewRow,"COMPARTMENTS",$Compartment,1);
							$self->{_compound_table}->add_data($NewRow,"TRANSPORTERS",$ID,1);
						} else {
							$self->{_compound_table}->add_data($NewRow,"COMPARTMENTS","c",1);
						}
					}
				}
			}
		}
	}
	return $self->{_compound_table};
}
=head3 generate_compound_data_table
Definition:
	FIGMODELtable = FIGMODELmodel->generate_compound_data_table({
		...
	});
Description:
	Creates a table of model compound data
=cut
sub generate_compound_data_table {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		-formula => 1,
		-mass => 1,
		-primname => 1,
		-charge => 1,
		-abbrev => 1,
		-name => 1,
		-kegg => 1,
		-deltaG => 1,
		-deltaGerr => 1,
		-biomass => 1,
		-compartments => 1
	});
	if (defined($args->{error})) {return $self->error_message({function => "generate_compound_data_table",args => $args});}
	my $headingArgHash = {
		FORMULA => "-formula",
		MASS => "-mass",
		"PRIMARY NAME" => "-primname",
		CHARGE => "-charge",
		ABBREVIATION => "-abbrev",
		NAMES => "-name",
		"KEGG ID(S)" => "-kegg",
		"DELTAG (kcal/mol)" => "-deltaG",
		"DELTAG ERROR (kcal/mol)" => "-deltaGerr",
		BIOMASS => "-biomass",
		COMPARTMENTS => "-compartments"
	};
	my $headings = ["DATABASE"];
	my $fullOrderedList = ["PRIMARY NAME","ABBREVIATION","NAMES","KEGG ID(S)","FORMULA","CHARGE","DELTAG (kcal/mol)","DELTAG ERROR (kcal/mol)","MASS"];
	foreach my $flag (@{$fullOrderedList}) {
		if (!defined($headingArgHash->{$flag}) || !defined($args->{$headingArgHash->{$flag}}) || $args->{$headingArgHash->{$flag}} == 1) {
			push(@{$headings},$flag);
		}
	}
	my $keggHash = $self->figmodel()->database()->get_object_hash({type=>"cpdals",attribute=>"COMPOUND",parameters=>{type => "KEGG"},useCache=>1});
	my $nameHash = $self->figmodel()->database()->get_object_hash({type=>"cpdals",attribute=>"COMPOUND",parameters=>{type => "name"},useCache=>1});
	my $cpdHash = $self->figmodel()->database()->get_object_hash({type=>"compound",attribute=>"id"},useCache=>1);
	my $cpdtbl = $self->compound_table();
	my $outputTbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$self->directory()."CompoundTable-".$self->id().".tbl",undef,"\t","|",undef);	
	for (my $i=0; $i < $cpdtbl->size();$i++) {
		my $newRow;
		my $row = $cpdtbl->get_row($i);
		my $obj;
		if (defined($cpdHash->{$row->{DATABASE}->[0]})) {
			$obj = $cpdHash->{$row->{DATABASE}->[0]}->[0];
		}
		if (defined($obj)) {
			for (my $j=0; $j < @{$headings}; $j++) {
				if ($headings->[$j] eq "DATABASE") {
					$newRow->{$headings->[$j]}->[0] = $row->{DATABASE}->[0];
				} elsif ($headings->[$j] eq "FORMULA" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->formula();
				} elsif ($headings->[$j] eq "MASS" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->mass();
				} elsif ($headings->[$j] eq "CHARGE" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->charge();
				} elsif ($headings->[$j] eq "PRIMARY NAME" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->name();
				} elsif ($headings->[$j] eq "ABBREVIATION" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->abbrev();
				} elsif ($headings->[$j] eq "KEGG ID(S)" && defined($keggHash->{$obj->id()})) {
					for (my $k=0; $k < @{$keggHash->{$obj->id()}}; $k++) {
						push(@{$newRow->{$headings->[$j]}},$keggHash->{$obj->id()}->[$k]->alias());
					}
				} elsif ($headings->[$j] eq "DELTAG (kcal/mol)" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaG();
				} elsif ($headings->[$j] eq "DELTAG ERROR (kcal/mol)" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaGErr();
				} elsif ($headings->[$j] eq "COMPARTMENTS" && defined($row->{COMPARTMENTS})) {
					$newRow->{$headings->[$j]} = $row->{COMPARTMENTS};
				} elsif ($headings->[$j] eq "BIOMASS" && defined($row->{BIOMASS})) {
					$newRow->{$headings->[$j]}->[0] = "yes";
				} elsif ($headings->[$j] eq "NAMES" && defined($nameHash->{$row->{DATABASE}->[0]})) {
					for (my $k=0; $k < @{$nameHash->{$row->{DATABASE}->[0]}}; $k++) {
						push(@{$newRow->{$headings->[$j]}},$nameHash->{$row->{DATABASE}->[0]}->[$k]->alias());
					}
				}
			}
		}
		$outputTbl->add_row($newRow);	
	}
	return $outputTbl;
}
=head3 feature_table
Definition:
	FIGMODELTable = FIGMODELmodel->feature_table();
Description:
	Returns FIGMODELTable with the feature list for the model
=cut
sub feature_table {
	my ($self) = @_;
	if (!defined($self->{_feature_data})) {
		#Getting the genome feature list
		my $FeatureTable = $self->figmodel()->GetGenomeFeatureTable($self->genome());
		if (!defined($FeatureTable)) {
			print STDERR "FIGMODELmodel:feature_table:Could not get features for genome ".$self->genome()." in database!";
			return undef;
		}
		#Getting the reaction table for the model
		my $rxnTable = $self->reaction_table();
		if (!defined($rxnTable)) {
			print STDERR "FIGMODELmodel:feature_table:Could not get reaction table for model ".$self->id()." in database!";
			return undef;
		}
		#Cloning the feature table
		$self->{_feature_data} = $FeatureTable->clone_table_def();
		$self->{_feature_data}->add_headings(($self->id()."REACTIONS",$self->id()."PREDICTIONS"));
		for (my $i=0; $i < $rxnTable->size(); $i++) {
			my $Row = $rxnTable->get_row($i);
			if (defined($Row) && defined($Row->{"ASSOCIATED PEG"})) {
				foreach my $GeneSet (@{$Row->{"ASSOCIATED PEG"}}) {
					my $temp = $GeneSet;
					$temp =~ s/\+/|/g;
					  $temp =~ s/\sAND\s/|/gi;
					  $temp =~ s/\sOR\s/|/gi;
					  $temp =~ s/[\(\)\s]//g;
					  my @GeneList = split(/\|/,$temp);
					  foreach my $Gene (@GeneList) {
						  my $FeatureRow = $self->{_feature_data}->get_row_by_key("fig|".$self->genome().".".$Gene,"ID");
						  if (!defined($FeatureRow)) {
							$FeatureRow = $FeatureTable->get_row_by_key("fig|".$self->genome().".".$Gene,"ID");
							if (defined($FeatureRow)) {
								$self->{_feature_data}->add_row($FeatureRow);
							}
						  }
						 if (defined($FeatureRow)) {
							$self->{_feature_data}->add_data($FeatureRow,$self->id()."REACTIONS",$Row->{"LOAD"}->[0],1);
						  }
					  }
				}
			  }
		}
		#Loading predictions
		my $objects = $self->figmodel()->database()->get_objects("mdless",{parameters=>"NONE",MODEL=>$self->id()});
		my $mediaHash;
		for (my $i=0; $i < @{$objects}; $i++) {
			my @list = split(/;/,$objects->[$i]->essentials());
			for (my $j=0; $j < @list; $j++) {
				$mediaHash->{$objects->[$i]->MEDIA()}->{$list[$j]} = 1;
			}
		}
		for (my $i=0; $i < $self->{_feature_data}->size(); $i++) {
			my $Row = $self->{_feature_data}->get_row($i);
			if ($Row->{ID}->[0] =~ m/(peg\.\d+)/) {
				my $gene = $1;
				foreach my $media (keys(%{$mediaHash})) {
					if (defined($mediaHash->{$media}->{$gene})) {
						push(@{$Row->{$self->id()."PREDICTIONS"}},$media.":essential");
					} else {
						push(@{$Row->{$self->id()."PREDICTIONS"}},$media.":nonessential");
					}
				}
			}
		}
	}
	return $self->{_feature_data};
}
=head3 generate_feature_data_table
Definition:
	FIGMODELtable = FIGMODELmodel->generate_feature_data_table({
		...
	});
Description:
	Creates a table of model compound data
=cut
sub generate_feature_data_table {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		-start => 1,
		-stop => 1,
		-direction => 1,
		-annotation => 1,
		-subsystems => 1,
		-reactions => 1,
		-predictedEssentiality => 1
	});
	if (defined($args->{error})) {return $self->error_message({function => "generate_feature_data_table",args => $args});}
	my $headingArgHash = {
		START => "-start",
		STOP => "-stop",
		DIRECTION => "-direction",
		ANNOTATION => "-annotation",
		SUBSYSTEMS => "-subsystems",
		REACTIONS => "-reactions",
		"PREDICTED ESSENTIALITY" => "-predictedEssentiality"
	};
	my $headings = ["SEED GENE ID"];
	my $fullOrderedList = ["START","STOP","DIRECTION","ANNOTATION","SUBSYSTEMS","REACTIONS","PREDICTED ESSENTIALITY"];
	foreach my $flag (@{$fullOrderedList}) {
		if (!defined($headingArgHash->{$flag}) || !defined($args->{$headingArgHash->{$flag}}) || $args->{$headingArgHash->{$flag}} == 1) {
			push(@{$headings},$flag);
		}
	}
	my $ftrTbl = $self->feature_table();
	my $outputTbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$self->directory()."FeatureTable-".$self->id().".tbl",undef,"\t","|",undef);	
	for (my $i=0; $i < $ftrTbl->size();$i++) {
		my $newRow;
		my $row = $ftrTbl->get_row($i);
		if ($row->{ID}->[0] =~ m/peg/) {
			for (my $j=0; $j < @{$headings}; $j++) {
				if ($headings->[$j] eq "SEED GENE ID") {
					$newRow->{$headings->[$j]}->[0] = $row->{ID}->[0];
				} elsif ($headings->[$j] eq "START") {
					$newRow->{$headings->[$j]}->[0] = $row->{"MIN LOCATION"}->[0];
				} elsif ($headings->[$j] eq "STOP") {
					$newRow->{$headings->[$j]}->[0] = $row->{"MAX LOCATION"}->[0];
				} elsif ($headings->[$j] eq "DIRECTION") {
					$newRow->{$headings->[$j]}->[0] = $row->{DIRECTION}->[0];
				} elsif ($headings->[$j] eq "ANNOTATION") {
					$newRow->{$headings->[$j]} = $row->{ROLES};
				} elsif ($headings->[$j] eq "SUBSYSTEMS") {
					#TODO
					$newRow->{$headings->[$j]}->[0] = "";
				} elsif ($headings->[$j] eq "REACTIONS" && defined($row->{$self->id()."REACTIONS"})) {
					$newRow->{$headings->[$j]} = $row->{$self->id()."REACTIONS"};
				} elsif ($headings->[$j] eq "PREDICTED ESSENTIALITY" && defined($row->{$self->id()."PREDICTIONS"})) {
					$newRow->{$headings->[$j]} = $row->{$self->id()."PREDICTIONS"};
				}
			}
			$outputTbl->add_row($newRow);
		}
	}
	return $outputTbl;
}
=head3 PrintModelLPFile
Definition:
	success()/fail() FIGMODELmodel->PrintModelLPFile();
Description:
	Prints the lp file needed to run the model using the mpifba program
=cut
sub PrintModelLPFile {
	my ($self,$exportForm) = @_;
	#Printing lp and key file for model
	my $UniqueFilename = $self->figmodel()->filename();
	#Printing the standard FBA file
	if (defined($exportForm) && $exportForm eq "1") {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),"NoBounds",["ProdFullFBALP"],{"Make all reactions reversible in MFA"=>0,"use simple variable and constraint names"=>0},$self->id().$self->selected_version()."-LPPrint.log",undef,$self->selected_version()));
		system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/CurrentProblem.lp ".$self->directory().$self->id().$self->selected_version().".lp");
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),"NoBounds",["ProdFullFBALP"],undef,$self->id().$self->selected_version()."-LPPrint.log",undef,$self->selected_version()));
		system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/CurrentProblem.lp ".$self->directory()."FBA-".$self->id().$self->selected_version().".lp");
	}
	my $KeyTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/VariableKey.txt",";","|",0,undef);
	if (!defined($KeyTable)) {
		print STDERR "FIGMODEL:RunAllStudiesWithDataFast: ".$self->id()." LP file could not be printed.\n";
		return 0;
	}
	$KeyTable->headings(["Variable type","Variable ID"]);
	$KeyTable->save($self->directory()."FBA-".$self->id().$self->selected_version().".key");
	unlink($self->config("database message file directory")->[0].$self->id().$self->selected_version()."-LPPrint.log");
	$self->figmodel()->clearing_output($UniqueFilename,"FBA-".$self->id().$self->selected_version().".lp");
}

=head3 patch_model
Definition:
	FIGMODELmodel->patch_model([] -or- {} of patch arguments);
Description:
=cut
sub patch_model {
	my ($self,$arguments) = @_;
	my $genomeObj = $self->genomeObj();
	if ($self->ppo()->name() eq "Unknown") {
		print $genomeObj->name()."\n";
		$self->ppo()->name($genomeObj->name());
	}
	return;
	my $rxnTbl = $self->reaction_table();
	my $hash = $self->figmodel()->database()->get_object_hash({
		type => "reaction",
		attribute => "id",
	});
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		my $row = $rxnTbl->get_row($i);
		if (!defined($hash->{$row->{LOAD}->[0]}) && $row->{LOAD}->[0] !~ m/bio/) {
			$self->globalMessage({
				function => "patch_model",
				message => "bad reacton ".$row->{LOAD}->[0],
				thread => "stdout"
			});
		}
	}
	my $row = $rxnTbl->get_row_by_key("rxn10821","LOAD");
	if (defined($row)) {
		$self->removeReactions({
			ids => ["rxn10821"],
			compartments => ["c"],
			reason => "replacing rxn10821 with equivalent reaction rxn05513",
			user => "chenry",
			trackChanges => 1
		});
		$self->add_reactions({
			ids => ["rxn05513"],
			directionalitys => [$row->{DIRECTIONALITY}->[0]],
			compartments => [$row->{COMPARTMENT}->[0]],
			pegs => [$row->{"ASSOCIATED PEG"}],
			subsystems => [$row->{SUBSYSTEM}],
			confidences => [$row->{CONFIDENCE}->[0]],
			references => [$row->{REFERENCE}],
			notes => [$row->{NOTES}],
			reason => "replacing rxn10821 with equivalent reaction rxn05513",
			user => "chenry",
			adjustmentOnly => 0,
		});
	}
}

=head3 integrateUploadedChanges
Definition:
	FIGMODELmodel->integrateUploadedChanges();
Description:
=cut
sub integrateUploadedChanges {
	my ($self,$username) = @_;
	if (!-e $self->directory().$self->id()."-uploadtable.tbl") {
		return $self->error_message({function => "integrateUploadedChanges",message => "uploaded file not found for model!"});
	}
	my $tbl = $self->load_model_table("ModelReactionUpload",1);
	if (!defined($tbl)) {
		return $self->error_message({function => "integrateUploadedChanges",message => "could not load uploaded reaction table!"});
	}
	if (substr($tbl->prefix(),0,length($self->id())) ne $self->id()) {
		return $self->error_message({function => "integrateUploadedChanges",message => "model labeled in uploaded file does not match reference model!"});
	}
	my $newrxntbl = $self->reaction_table(1);
	if (!defined($newrxntbl)) {
		return $self->error_message({function => "integrateUploadedChanges",message => "could not load reaction table!"});
	}
	for (my $i=0; $i < $newrxntbl->size(); $i++) {
		my $row = $newrxntbl->get_row($i);
		my $newrow = $tbl->get_row_by_key($row->{LOAD}->[0],"DATABASE");
		if (!defined($newrow)) {
			$newrxntbl->delete_row($i);
			$i--;
		} else {
			$row->{DIRECTIONALITY} = $newrow->{DIRECTIONALITY};
			$row->{COMPARTMENT} = $newrow->{COMPARTMENT};
			$row->{"ASSOCIATED PEG"} = $newrow->{"ASSOCIATED PEG"};
			$row->{NOTES} = $newrow->{NOTES};
		}
	}
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		my $newrow = $newrxntbl->get_row_by_key($row->{DATABASE}->[0],"LOAD");
		if (!defined($newrow)) {
			$newrxntbl->add_row({LOAD=>$row->{DATABASE},DIRECTIONALITY=>$row->{DIRECTIONALITY},COMPARTMENT=>$row->{COMPARTMENT},"ASSOCIATED PEG"=>$row->{"ASSOCIATED PEG"},SUBSYSTEM=>["NONE"],CONFIDENCE=>[5],REFERENCE=>["NONE"],NOTES=>$row->{NOTES}});
		}
	}
	$self->calculate_model_changes($self->reaction_table(1),$username." modifications",$newrxntbl);
	$newrxntbl->save();
	$self->PrintSBMLFile();
	$self->PrintModelLPFile();
	$self->PrintModelLPFile(1);
	$self->PrintModelSimpleReactionTable();
	$self->update_model_stats();
	$self->calculate_growth()
}

=head3 translate_genes
Definition:
	FIGMODELmodel->translate_genes();
Description:
=cut
sub translate_genes {
	my ($self) = @_;
	
	#Loading gene translations
	if (!defined($self->{_gene_aliases})) {
		#Loading gene aliases from feature table
		my $tbl = $self->figmodel()->GetGenomeFeatureTable($self->genome());
		if (defined($tbl)) {
			for (my $i=0; $i < $tbl->size(); $i++) {
				my $row = $tbl->get_row($i);
				if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
					my $geneID = $1;
					for (my $j=0; $j < @{$row->{ALIASES}}; $j++) {
						$self->{_gene_aliases}->{$row->{ALIASES}->[$j]} = $geneID;
					}
				}
			}
		}
		#Loading additional gene aliases from the database
		if (-e $self->figmodel()->config("Translation directory")->[0]."AdditionalAliases/".$self->genome().".txt") {
			my $AdditionalAliases = $self->figmodel()->database()->load_multiple_column_file($self->figmodel()->config("Translation directory")->[0]."AdditionalAliases/".$self->genome().".txt","\t");
			for (my $i=0; $i < @{$AdditionalAliases}; $i++) {
				$self->{_gene_aliases}->{$AdditionalAliases->[$i]->[1]} = $AdditionalAliases->[$i]->[0];
			}
		}
	}
	
	#Cycling through reactions and translating genes
	for (my $i=0; $i < $self->reaction_table()->size(); $i++) {
		my $row = $self->reaction_table()->get_row($i);
		if (defined($row->{"ASSOCIATED PEG"})) {
			for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
				my $Original = $row->{"ASSOCIATED PEG"}->[$j];
				$Original =~ s/\sand\s/:/g;
				$Original =~ s/\sor\s/;/g;
				my @GeneNames = split(/[,\+\s\(\):;]/,$Original);
				foreach my $Gene (@GeneNames) {
					if (length($Gene) > 0 && defined($self->{_gene_aliases}->{$Gene})) {
						my $Replace = $self->{_gene_aliases}->{$Gene};
						$Original =~ s/([^\w])$Gene([^\w])/$1$Replace$2/g;
						$Original =~ s/^$Gene([^\w])/$Replace$1/g;
						$Original =~ s/([^\w])$Gene$/$1$Replace/g;
						$Original =~ s/^$Gene$/$Replace/g;
					}
				}
				$Original =~ s/:/ and /g;
				$Original =~ s/;/ or /g;
				$row->{"ASSOCIATED PEG"}->[$j] = $Original;
			}
		}
	}
	
	#Archiving model and saving reaction table
	$self->ArchiveModel();
	$self->reaction_table()->save();
}

=head3 feature_web_data
Definition:
	string:web output for feature/model connection = FIGMODELmodel->feature_web_data(FIGMODELfeature:feature);
Description:
=cut
sub feature_web_data {
	my ($self,$feature) = @_;
	#First checking if the feature is in the model
	if (!defined($feature->{$self->id()})) {
		return "Not in model";	
	}
	my $output;
	if (defined($feature->{$self->id()}->{reactions})) {
		my @reactionList = keys(%{$feature->{$self->id()}->{reactions}});
		for (my $i=0; $i < @reactionList; $i++) {
			my $rxnData = $self->get_reaction_data($reactionList[$i]);
			my $reactionString = $self->figmodel()->web()->create_reaction_link($reactionList[$i],join(" or ",@{$rxnData->{"ASSOCIATED PEG"}}),$self->id());
			if (defined($rxnData->{PREDICTIONS})) {
				my $predictionHash;
				for (my $i=0; $i < @{$rxnData->{PREDICTIONS}};$i++) {
					my @temp = split(/:/,$rxnData->{PREDICTIONS}->[$i]); 
					push(@{$predictionHash->{$temp[1]}},$temp[0]);
				}
				$reactionString .= "(";
				foreach my $key (keys(%{$predictionHash})) {
					if ($key eq "Essential =>") {
						$reactionString .= '<span title="Essential in '.join(",",@{$predictionHash->{$key}}).'">E=></span>,';
					} elsif ($key eq "Essential <=") {
						$reactionString .= '<span title="Essential in '.join(",",@{$predictionHash->{$key}}).'">E<=</span>,';
					} elsif ($key eq "Active =>") {
						$reactionString .= '<span title="Active in '.join(",",@{$predictionHash->{$key}}).'">A=></span>,';
					} elsif ($key eq "Active <=") {
						$reactionString .= '<span title="Active in '.join(",",@{$predictionHash->{$key}}).'">A<=</span>,';
					} elsif ($key eq "Active <=>") {
						$reactionString .= '<span title="Active in '.join(",",@{$predictionHash->{$key}}).'">A</span>,';
					} elsif ($key eq "Inactive") {
						$reactionString .= '<span title="Inactive in '.join(",",@{$predictionHash->{$key}}).'">I</span>,';
					} elsif ($key eq "Dead") {
						$reactionString .= '<span title="Dead">D</span>,';
					}
				}
				$reactionString =~ s/,$/)/;
			}
			push(@{$output},$reactionString);
		}
	}
	if (defined($feature->{$self->id()}->{essentiality})) {
		my $essDataHash;
		if (defined($feature->{ESSENTIALITY})) {
			for (my $i=0; $i < @{$feature->{ESSENTIALITY}};$i++) {
				my @array = split(/:/,$feature->{ESSENTIALITY}->[$i]);
				$essDataHash->{$array[0]} = $array[1];
			}
		}
		my @mediaList = keys(%{$feature->{$self->id()}->{essentiality}});
		my $predictionHash;
		for(my $i=0; $i < @mediaList; $i++) {
			if (defined($essDataHash->{$mediaList[$i]})) {
				if ($essDataHash->{$mediaList[$i]} eq "essential") {
					if ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 0) {
						push(@{$predictionHash->{"False positive"}},$mediaList[$i]);	
					} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 1) {
						push(@{$predictionHash->{"Correct negative"}},$mediaList[$i]);
					}
				} else {
					if ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 0) {
						push(@{$predictionHash->{"Correct positive"}},$mediaList[$i]);	
					} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 1) {
						push(@{$predictionHash->{"False negative"}},$mediaList[$i]);
					}
				}
			} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 0) {
				push(@{$predictionHash->{"Nonessential"}},$mediaList[$i]);	
			} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 1) {
				push(@{$predictionHash->{"Essential"}},$mediaList[$i]);
			}
		}
		my @predictions = keys(%{$predictionHash});
		for(my $i=0; $i < @predictions; $i++) {
			my $predictionString = '<span title="'.$predictions[$i].' in '.join(",",@{$predictionHash->{$predictions[$i]}}).'">'.$predictions[$i].'</span>';
			push(@{$output},$predictionString);
		}
	}	
	#Returning output
	return join("<br>",@{$output});
}

=head3 remove_obsolete_reactions
Definition:
	void FIGMODELmodel->remove_obsolete_reactions();
Description:
=cut
sub remove_obsolete_reactions {
	my ($self) = @_;
	
	(my $dummy,my $translation) = $self->figmodel()->put_two_column_array_in_hash($self->figmodel()->database()->load_multiple_column_file($self->figmodel()->config("Translation directory")->[0]."ObsoleteRxnIDs.txt","\t"));
	my $rxnTbl = $self->reaction_table();
	if (defined($rxnTbl)) {
		for (my $i=0; $i < $rxnTbl->size(); $i++) {
			my $row = $rxnTbl->get_row($i);
			if (defined($translation->{$row->{LOAD}->[0]}) || defined($translation->{$row->{LOAD}->[0]."r"})) {
				my $direction = $row->{DIRECTION}->[0];
				my $newRxn;
				if (defined($translation->{$row->{LOAD}->[0]."r"})) {
					$newRxn = $translation->{$row->{LOAD}->[0]."r"};
					if ($direction eq "<=") {
						$direction = "=>";
					} elsif ($direction eq "=>") {
						$direction = "<=";
					}
				} else {
					$newRxn = $translation->{$row->{LOAD}->[0]};
				}
				#Checking if the new reaction is already in the model
				my $newRow = $rxnTbl->get_row_by_key($newRxn,"LOAD");
				if (defined($newRow)) {
					#Handling direction
					if ($newRow->{DIRECTION}->[0] ne $direction) {
						$newRow->{DIRECTION}->[0] = "<=>";
					}
					push(@{$row->{"ASSOCIATED PEG"}},@{$rxnTbl->get_row($i)->{"ASSOCIATED PEG"}});
				} else {
					$rxnTbl->get_row($i)->{LOAD}->[0] = $newRxn;
					$rxnTbl->get_row($i)->{DIRECTION}->[0] = $direction;
				}
			}
		}
		$rxnTbl->save();
	}
}

=pod

=item * [string]:I<list of essential genes> = B<run_geneKO_slow> (string:I<media>,0/1:I<max growth>,0/1:I<save results>);

=cut

sub run_geneKO_slow {
	my ($self,$media,$maxGrowth,$save) = @_;
	my $output;
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($maxGrowth) && $maxGrowth == 1) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"perform single KO experiments" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.999},"SlowGeneKO-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"perform single KO experiments" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.1},"SlowGeneKO-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	}	
	if (!-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."DeletionStudyResults.txt") {
		print "Deletion study file not found!.\n";
		return undef;	
	}
	my $deltbl = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."DeletionStudyResults.txt",";","|",1,["Experiment"]);
	for (my $i=0; $i < $deltbl->size(); $i++) {
		my $row = $deltbl->get_row($i);
		if ($row->{"Insilico growth"}->[0] < 0.0000001) {
			push(@{$output},$row->{Experiment}->[0]);	
		}
	}
	if (defined($output)) {
		if (defined($save) && $save == 1) {
			my $tbl = $self->essentials_table();
			my $row = $tbl->get_row_by_key($media,"MEDIA",1);
			$row->{"ESSENTIAL GENES"} = $output;
			$tbl->save();
		}
	}
	return $output;
}

=pod

=item * [string]:I<list of minimal genes> = B<run_gene_minimization> (string:I<media>,0/1:I<max growth>,0/1:I<save results>);

=cut

sub run_gene_minimization {
	my ($self,$media,$maxGrowth,$save) = @_;
	my $output;
	
	#Running the MFAToolkit
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($maxGrowth) && $maxGrowth == 1) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"optimize organism genes" => 1,"MFASolver" => "CPLEX","Constrain objective to this fraction of the optimal value" => 0.999},"MinimizeGenes-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"optimize organism genes" => 1,"MFASolver" => "CPLEX","Constrain objective to this fraction of the optimal value" => 0.1},"MinimizeGenes-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	}
	my $tbl = $self->figmodel()->LoadProblemReport($UniqueFilename);
	if (!defined($tbl)) {
		return undef;	
	}
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		if ($row->{Notes}->[0] =~ m/Recursive\sMILP\sGENE_USE\soptimization/) {
			my @array = split(/\|/,$row->{Notes}->[0]);
			my $solution = $array[0];
			$_ = $solution;
			my @OriginalArray = /(peg\.\d+)/g;
			push(@{$output},@OriginalArray);
			last;
		}	
	}
	
	if (defined($output)) {
		if (defined($save) && $save == 1) {
			my $tbl = $self->load_model_table("MinimalGenes");
			my $row = $tbl->get_table_by_key("MEDIA",$media)->get_row_by_key("MAXGROWTH",$maxGrowth);
			if (defined($row)) {
				$row->{GENES} = $output;
			} else {
				$tbl->add_row({GENES => $output,MEDIA => [$media],MAXGROWTH => [$maxGrowth]});
			}
			$tbl->save();
		}
	}
	return $output;
}

=pod

=item * [string]:I<list of inactive genes> = B<identify_inactive_genes> (string:I<media>,0/1:I<max growth>,0/1:I<save results>);

=cut

sub identify_inactive_genes {
	my ($self,$media,$maxGrowth,$save) = @_;
	my $output;
	#Running the MFAToolkit
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($maxGrowth) && $maxGrowth == 1) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"find tight bounds" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.999},"Classify-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"find tight bounds" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.1},"Classify-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	}
	#Reading in the output bounds file
	my $ReactionTB;
	if (-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/MFAOutput/TightBoundsReactionData0.txt") {
		$ReactionTB = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/MFAOutput/TightBoundsReactionData0.txt",";","|",1,["DATABASE ID"]);
	}
	if (!defined($ReactionTB)) {
		print STDERR "FIGMODEL:ClassifyModelReactions: Classification file not found when classifying reactions in ".$self->id().$self->selected_version()." with ".$media." media. Most likely the model did not grow.\n";
		return undef;
	}
	#Clearing output
	$self->figmodel()->clearing_output($UniqueFilename,"Classify-".$self->id().$self->selected_version()."-".$UniqueFilename.".log");
	my $geneHash;
	my $activeGeneHash;
	for (my $i=0; $i < $ReactionTB->size(); $i++) {
		my $Row = $ReactionTB->get_row($i);
		if (defined($Row->{"Min FLUX"}) && defined($Row->{"Max FLUX"}) && defined($Row->{"DATABASE ID"}) && $Row->{"DATABASE ID"}->[0] =~ m/rxn\d\d\d\d\d/) {
			my $data = $self->get_reaction_data($Row->{"DATABASE ID"}->[0]);
			if (defined($data->{"ASSOCIATED PEG"})) {
				my $active = 0;
				if ($Row->{"Min FLUX"}->[0] > 0.00000001 || $Row->{"Max FLUX"}->[0] < -0.00000001 || ($Row->{"Max FLUX"}->[0]-$Row->{"Min FLUX"}->[0]) > 0.00000001) {
					$active = 1;
				}	
				for (my $j=0; $j < @{$data->{"ASSOCIATED PEG"}}; $j++) {
					$_ = $data->{"ASSOCIATED PEG"}->[$j];
					my @OriginalArray = /(peg\.\d+)/g;
					for (my $k=0; $k < @OriginalArray; $k++) {
						if ($active == 1) {
							$activeGeneHash->{$OriginalArray[$k]} = 1;
						}
						$geneHash->{$OriginalArray[$k]} = 1;
					}
				}	
			}
		}
	}
	my @allGenes = keys(%{$geneHash});
	for (my $i=0; $i < @allGenes; $i++) {
		if (!defined($activeGeneHash->{$allGenes[$i]})) {
			push(@{$output},$allGenes[$i]);
		}
	}
	if (defined($output)) {
		if (defined($save) && $save == 1) {
			my $tbl = $self->load_model_table("InactiveGenes");
			my $row = $tbl->get_table_by_key("MEDIA",$media)->get_row_by_key("MAXGROWTH",$maxGrowth);
			if (defined($row)) {
				$row->{GENES} = $output;
			} else {
				$tbl->add_row({GENES => $output,MEDIA => [$media],MAXGROWTH => [$maxGrowth]});
			}
			$tbl->save();
		}
	}
	return $output;
}

sub ConvertVersionsToHistoryFile {
	my ($self) = @_;
	my $vone = 0;
	my $vtwo = 0;
	my $continue = 1;
	my $lastTable;
	my $currentTable;
	my $cause;
	my $lastChanged = 0;
	my $noHitCount = 0;
	while ($continue == 1) {
		$cause = "NONE";
		$currentTable = undef;
		if (-e $self->directory().$self->id()."V".($vone+1).".".$vtwo.".txt") {
			$noHitCount = 0;
			$lastChanged = 0;
			$vone = $vone+1;
			$currentTable = $self->figmodel()->database()->load_table($self->directory().$self->id()."V".$vone.".".$vtwo.".txt",";","|",1,["LOAD","DIRECTIONALITY","COMPARTMENT","ASSOCIATED PEG"]);	
			$cause = "RECONSTRUCTION";
		} elsif (-e $self->directory().$self->id()."V".$vone.".".($vtwo+1).".txt") {
			$noHitCount = 0;
			$lastChanged = 0;
			$vtwo = $vtwo+1;
			$currentTable = $self->figmodel()->database()->load_table($self->directory().$self->id()."V".$vone.".".$vtwo.".txt",";","|",1,["LOAD","DIRECTIONALITY","COMPARTMENT","ASSOCIATED PEG"]);	
			$cause = "AUTOCOMPLETION";
		} elsif ($lastChanged == 0) {
			$lastChanged = 1;
			$vone = $vone+1;
			$cause = "RECONSTRUCTION";
		} elsif ($lastChanged == 1) {
			$lastChanged = 2;
			$vone = $vone-1;
			$vtwo = $vtwo+1;
			$cause = "AUTOCOMPLETION";
		} elsif ($lastChanged == 2) {
			$lastChanged = 0;
			$vone = $vone+1;
			$cause = "RECONSTRUCTION";
		}
		if (defined($currentTable)) {
			if (defined($lastTable)) {
				print $cause."\t".$self->directory().$self->id()."V".$vone.".".$vtwo.".txt\n";
				$self->calculate_model_changes($lastTable,$cause,$currentTable,"V".$vone.".".$vtwo);
			}
			$lastTable = $currentTable;
		} else {
			$noHitCount++;
			if ($noHitCount >= 40) {
				last;
			}
		}
	}
}

=head2 Flux Balance Analysis Methods

=head3 fba
Definition:
	FIGMODELfba = FIGMODELmodel->fba();
Description:
	Returns a FIGMODELfba object for the specified model
=cut
sub fba {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		model => $self->id(),
		figmodel => $self->figmodel(),
		parameter_files=>["ProductionMFA"]
	});
	return ModelSEED::FIGMODEL::FIGMODELfba->new($args);
}
=head3 runFBAStudy
Definition:
	Output = FIGMODELmodel->runFBAStudy({
		fbaStartParameters => {
			parameters=>{}:parameters,
			filename=>string:filename,
			geneKO=>[string]:gene ids,
			rxnKO=>[string]:reaction ids,
			model=>string:model id,
			media=>string:media id,
			parameter_files=>[string]:parameter files
		}
		setupParameters => {
			function => ?,
			arguments => {}
		},
		problemDirectory => undef,
		parameterFile => "FBAParameters.txt",
		startFresh => 1,
		printToScratch => 1,
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem=>0
		clearOutput=>0/(1):indicates if job directory should be deleted upon job completion
	});
	Output: {
		arguments => {},
		fbaObj => FIGMODELfba,
		RESULT KEYS WHICH DEPEND UPON THE STUDY RUN   
	}
Description:
=cut
sub runFBAStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		fbaStartParameters => {},
		setupParameters => undef,
		problemDirectory => undef,
		parameterFile => "FBAParameters.txt",
		startFresh => 1,
		printToScratch => $self->figmodel()->config("print to scratch")->[0],
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem=>0,
		clearOutput=>0
	});	
	#Setting the problem directory
	my $fbaObj = $self->fba($args->{fbaStartParameters});
	if (!defined($args->{problemDirectory})) {
		$args->{problemDirectory} = $fbaObj->filename();
	}
	$fbaObj->filename($args->{problemDirectory});
	#Creating the output directory
	$fbaObj->makeOutputDirectory({deleteExisting => $args->{startFresh}});
	#Creating model file
	print "Creating the model file: ",$fbaObj->directory()."/".$self->id().".tbl\n";
	if (!-e $fbaObj->directory()."/".$self->id().".tbl" || $args->{forcePrintModel} == 1) {
		$self->printModelFileForMFAToolkit({
			removeGapfilling => $args->{removeGapfillingFromModel},
			filename => $fbaObj->directory()."/".$self->id().".tbl"
		});
	}
	my $function;
	if (defined($args->{setupParameters}) && defined($args->{setupParameters}->{function})) {
		$function = $args->{setupParameters}->{function};
		$fbaObj->$function($args->{setupParameters}->{arguments});
	}
	print "Creating biochemistry provenance files\n";
	if (-e $self->directory()."biochemistry/reaction.txt") {
		File::Copy::copy($self->directory()."biochemistry/reaction.txt",$fbaObj->directory()."/reactionDataFile.tbl");
		$fbaObj->dataFilename({type=>"reactions",filename=>$fbaObj->directory()."/reactionDataFile.tbl"});
	}
	if (-e $self->directory()."biochemistry/compound.txt") {
		File::Copy::copy($self->directory()."biochemistry/compound.txt",$fbaObj->directory()."/compoundDataFile.tbl");
		$fbaObj->dataFilename({type=>"compounds",filename=>$fbaObj->directory()."/compoundDataFile.tbl"});
	}
	File::Path::mkpath($fbaObj->directory()."/reaction/");
	my $bioRxn=$self->biomassReaction();
	if(!defined($bioRxn) || $bioRxn eq "NONE"){
		ModelSEED::FIGMODEL::FIGMODELERROR("Model ".$self->id()." does not contain a biomass function");
		return;
	}
	$self->figmodel()->get_reaction($bioRxn)->print_file_from_ppo({filename => $fbaObj->directory()."/reaction/".$bioRxn});
	$fbaObj->createProblemDirectory({
		parameterFile => $args->{parameterFile},
		printToScratch => $args->{printToScratch}
	});
	if ($args->{runProblem} != 1) {
		return {success => 1,arguments => $args,fbaObj => $fbaObj};
	}
	$fbaObj->runFBA({
		printToScratch => $args->{printToScratch},
		studyType => "LoadCentralSystem",
		parameterFile => "AddnlFBAParameters.txt"
	});
	my $results = $fbaObj->runParsingFunction();
	$results->{arguments} = $args;
	$results->{fbaObj} = $fbaObj;
	if ($args->{clearOutput} == 1) {
		$fbaObj->clearOutput();	
	}
	return $results;
}
=head3 fbaDefaultStudies
Definition:
	Output = FIGMODELmodel->fbaDefaultStudies({media => string:media ID});
Description:
=cut
sub fbaDefaultStudies {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		mediaList => [split(/\|/,$self->ppo()->defaultStudyMedia())],
		fbaStartParameters => {},
		problemDirectory => undef,
		singleKO => 1,
		classification => 1,
	});
	if (ref($args->{mediaList}) ne 'ARRAY') {
		$args->{mediaList} = [$args->{mediaList}];
	}
	for (my $i=0; $i < @{$args->{mediaList}}; $i++) {
		#Calculating growth
		my $saveLPFile = 0;
		if ($args->{mediaList}->[$i] eq "Complete") {
			$saveLPFile = 1;
		}
		$args->{fbaStartParameters}->{media} = $args->{mediaList}->[$i];
		my $results = $self->fbaCalculateGrowth({
			saveLPfile => $saveLPFile,
			fbaStartParameters => $args->{fbaStartParameters},
			problemDirectory => $args->{problemDirectory}
		});
	  	#Performing additional studies if growth occurs
	  	if (defined($results->{growth}) && $results->{growth} > 0.0001) {
			if ($results->{growth} > 0) {
				if ($args->{singleKO} == 1) {
					$self->fbaComboDeletions({
				   		maxDeletions => 1,
						saveKOResults => 1,
						problemDirectory => $args->{problemDirectory},
						fbaStartParameters => $args->{fbaStartParameters}
					});
				}
				if ($args->{classification} == 1) {
					$self->fbaFVA({
						options=>["forceGrowth"],
						saveFVAResults=>1,		
						problemDirectory => $args->{problemDirectory},
						fbaStartParameters => $args->{fbaStartParameters}	
					});
				}
			}
	  	}
	  	#Running FVA without growth to identify inactive reactions with no growth and with growth drains
		if ($args->{mediaList}->[$i] eq "Complete" && $args->{classification} == 1) {
			$results = $self->fbaFVA({
				options=>["noGrowth"],
				saveFVAResults=>1,		
				problemDirectory => $args->{problemDirectory},
				fbaStartParameters => $args->{fbaStartParameters}
			});
			$args->{fbaStartParameters}->{drnRxn} = ["bio00001"];
			$results = $self->fbaFVA({
				options=>["noGrowth"],
				saveFVAResults=>1,		
				problemDirectory => $args->{problemDirectory},
				fbaStartParameters => 
			});
			$args->{fbaStartParameters}->{drnRxn} = [];
		}
	}
	return undef;
}
=head3 fbaComboDeletions
Definition:
	Output = FIGMODELmodel->fbaComboDeletions({
		maxDeletions => INTEGER:maximum number of deletions
	});
	Output = {
		essentialGenes => [string]:gene IDs,
		knockoutGrowth => {string:gene set => double:knockout viability},
		wildtype => double
	}
Description:
	Simulating knockout of genes in model
=cut
sub fbaComboDeletions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
	   	maxDeletions => 1,
		saveKOResults => 1,
		problemDirectory => undef,
		fbaStartParameters => {
			media => "Complete"	
		}
	}); 
	my $results = $self->runFBAStudy({
		fbaStartParameters => $args->{fbaStartParameters},
		setupParameters => {
			function => "setCombinatorialDeletionStudy",
			arguments => {
				maxDeletions=>$args->{maxDeletions},
			} 
		},
		problemDirectory => $args->{problemDirectory},
		parameterFile => "CombinatorialDeletionStudy.txt",
		startFresh => 1,
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem => 1,
		clearOuput => 1
	});
	ModelSEED::FIGMODEL::FIGMODELERROR("Could not load results for combination knockout study") if (!defined($results->{Wildtype}));	
	my $output = {wildtype => $results->{Wildtype}};
	foreach my $genes (keys(%{$results})) {
		if ($results->{$genes} < 0.000001) {
			if ($genes !~ m/;/ && $genes =~ m/peg/) {
				push(@{$output->{essentialGenes}},$genes);
			}
		}
		if ($genes =~ m/peg/) {
			$output->{knockoutGrowth}->{$genes} = $results->{$genes}/$output->{wildtype};
		}
	}
	if ($args->{saveKOResults} == 1) {
		my $tbl = $self->essentials_table();
		my $row = $tbl->get_row_by_key($self->{media},"MEDIA",1);
		$row->{"ESSENTIAL GENES"} = $output->{essentialGenes};
		$tbl->save();
		my $obj = $self->figmodel()->database()->get_object("mdless",{parameters => "NONE",MODEL => $self->id(),MEDIA => $args->{media}});
		if (!defined($obj)) {
			$obj = $self->figmodel()->database()->create_object("mdless",{parameters => "NONE",MODEL => $self->id(),MEDIA => $args->{media}});	
		}
		$obj->essentials(join(";",@{$output->{essentialGenes}}));
	}  
	return $output;
}
=head3 fbaFVA
Definition:
	{}:Output = FIGMODELmodel->fbaFVA({
		
	});
Description:
	This function uses the MFAToolkit to minimize and maximize the flux through every reaction in the input model during minimal growth on the input media.
	The results are returned in a hash of strings where the keys are the reaction IDs and the strings are structured as follows: "Class;Min flux;Max flux".
	Possible values for "Class" include:
	1.) Positive: these reactions are essential in the forward direction.
	2.) Negative: these reactions are essential in the reverse direction.
	3.) Positive variable: these reactions are nonessential, but they only ever proceed in the forward direction.
	4.) Negative variable: these reactions are nonessential, but they only ever proceed in the reverse direction.
	5.) Variable: these reactions are nonessential and proceed in the forward or reverse direction.
	6.) Blocked: these reactions never carry any flux at all in the media condition tested.
	7.) Dead: these reactions are disconnected from the network.
=cut
sub fbaFVA {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
	   	saveformat => "EXCEL",
	   	directory => $self->figmodel()->config("database message file directory")->[0],
	   	filename => "FBAFVA_".$self->id().".xls",
	   	saveFVAResults=>1,
	   	variables => ["FLUX","UPTAKE"],
		problemDirectory => undef,
		fbaStartParameters => {
			media => "Complete",
			drnRxn => [],
			options => {forceGrowth => 1}
		}
	});
	#Running FBA study with selected options
	my $results = $self->runFBAStudy({
		fbaStartParameters => $args->{fbaStartParameters},
		setupParameters => {
			function => "setTightBounds",
			arguments => {
				variables => $args->{variables}
			}
		},
		problemDirectory => $args->{problemDirectory},
		parameterFile => "FluxVariabilityAnalysis.txt",
		startFresh => 1,
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem => 1,
		clearOuput => 1
	});
	#Checking that results were returned
	ModelSEED::FIGMODEL::FIGMODELERROR("No results returned by flux balance analysis.") if (!defined($results->{tb}));
	my $rxntbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Compartment"],$args->{directory}."Reactions-".$args->{filename},["Reaction"],";","|");
	my $cpdtbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Compound","Compartment"],$args->{directory}."Compounds-".$args->{filename},["Compound"],";","|");
	my $varAssoc = {
		FLUX => "reaction",
		DELTAG => "reaction",
		SDELTAG => "reaction",
		UPTAKE => "compound",
		SDELTAGF => "compound",
		POTENTIAL => "compound",
		CONC => "compound"
	};
	my $varHeading = {
		FLUX => "",
		DELTAG => " DELTAG",
		SDELTAG => " SDELTAG",
		UPTAKE => "",
		SDELTAGF => " SDELTAGF",
		POTENTIAL => " POTENTIAL",
		CONC => " CONC"
	};
	for (my $i=0; $i < @{$args->{variables}}; $i++) {
		if (defined($varAssoc->{$args->{variables}->[$i]})) {
			if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
				$cpdtbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "UPTAKE") {
					$cpdtbl->add_headings(("Class"));
				}
			} elsif ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
				$rxntbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "FLUX") {
					$rxntbl->add_headings(("Class"));
				}
			}
		}
	}
	foreach my $obj (keys(%{$results->{tb}})) {
		my $newRow;
		if ($obj =~ m/([rb][xi][no]\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Reaction"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			#$newRow->{"Direction"} = [$rxnObj->directionality()];
			#$newRow->{"Associated peg"} = [split(/\|/,$rxnObj->pegs())];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			#print Data::Dumper->Dump([$newRow]);
			$rxntbl->add_row($newRow);
		} elsif ($obj =~ m/(cpd\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Compound"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			$cpdtbl->add_row($newRow);
		}
	}
	#Saving data to file
	if ($args->{saveformat} eq "EXCEL") {
		$self->figmodel()->make_xls({
			filename => $args->{directory}.$args->{filename},
			sheetnames => ["Compound Bounds","Reaction Bounds"],
			sheetdata => [$cpdtbl,$rxntbl]
		});
	} elsif ($args->{saveformat} eq "TEXT") {
		$cpdtbl->save();
		$rxntbl->save();
	}
	#Loading data into database if requested
	if ($args->{saveFVAResults} == 1) {
		my $parameters = "";
		if (defined($args->{fbaStartParameters}->{forceGrowth}) && $args->{fbaStartParameters}->{forceGrowth} == 1) {
			$parameters .= "FG;";
		} elsif (defined($args->{fbaStartParameters}->{noGrowth}) && $args->{fbaStartParameters}->{noGrowth} == 1) {
			$parameters .= "NG;";
		}
		if (defined($args->{fbaStartParameters}->{drnRxn})) {
			$parameters .= "DR:".join("|",@{$args->{drnRxn}}).";";
		}
		if (defined($args->{fbaStartParameters}->{rxnKO})) {
			$parameters .= "RK:".join("|",@{$args->{rxnKO}}).";";
		}
		if (defined($args->{fbaStartParameters}->{geneKO})) {
			$parameters .= "GK:".join("|",@{$args->{geneKO}}).";";
		}
		if (length($parameters) == 0) {
			$parameters = "NONE";	
		}
		#Loading and updating the PPO FVA table, which will ultimately replace the flatfile tables
		my $obj = $self->figmodel()->database()->get_object("mdlfva",{parameters => $parameters,MODEL => $self->id(),MEDIA => $args->{media}});
		if (!defined($obj)) {
			$obj = $self->figmodel()->database()->create_object("mdlfva",{parameters => $parameters,MODEL => $self->id(),MEDIA => $args->{media}});	
		}
		my $headings = ["inactive","dead","positive","negative","variable","posvar","negvar","positiveBounds","negativeBounds","variableBounds","posvarBounds","negvarBounds"];
		for (my $i=0; $i < @{$headings}; $i++) {
			my $function = $headings->[$i];
			$obj->$function($results->{$function});
		}
	}	
	return $results;
}
=head3 fbaCalculateGrowth
Definition:
	{}:Output = FIGMODELmodel->fbaCalculateGrowth({
		growth => double,
		noGrowthCompounds => string:compound list	
	});
Description:
	Calculating growth in the input media
=cut
sub fbaCalculateGrowth {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		fbaStartParameters => {},
		problemDirectory => undef,
		outputDirectory => "",
		saveLPfile => 0
	});
	if (!defined($args->{fbaStartParameters}->{media})) {
		$args->{fbaStartParameters}->{media} = "Complete";
	}
	$args->{fbaStartParameters}->{parameters}->{"optimize metabolite production if objective is zero"} = 1;
	my $result = $self->runFBAStudy({
		fbaStartParameters => $args->{fbaStartParameters},
		setupParameters => {
			function => "setSingleGrowthStudy",
			arguments => {}
		},
		problemDirectory => $args->{problemDirectory},
		parameterFile => "fbaCalculateGrowth.txt",
		startFresh => 1,
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem=>1
	});
	$self->ppo()->growth($result->{growth});
	$self->ppo()->noGrowthCompounds($result->{noGrowthCompounds});
	if (-d $args->{outputDirectory} && $result->{growth} > 0.00000001 && -e $result->{fbaObj}->directory()."/MFAOutput/SolutionReactionData0.txt") {
		system("cp ".$result->{fbaObj}->directory()."/MFAOutput/SolutionReactionData0.txt ".$args->{outputDirectory}."Fluxes-".$self->id()."-".$args->{fbaStartParameters}->{media}.".txt");
		system("cp ".$result->{fbaObj}->directory()."/MFAOutput/SolutionCompoundData0.txt ".$args->{outputDirectory}."CompoundFluxes-".$self->id()."-".$args->{fbaStartParameters}->{media}.".txt");  
	}
	#Copying the LP file into the model directory
	if ($args->{saveLPfile} == 1 && -e $result->{fbaObj}->directory()."/CurrentProblem.lp") {
		system("cp ".$result->{fbaObj}->directory()."/CurrentProblem.lp ".$self->directory().$self->id().".lp");
	}
	$result->{fbaObj}->clearOutput();
	return $result;
}
=head3 fbaCalculateMinimalMedia
=item Definition:
	Output = FBAMODELmodel->fbaCalculateMinimalMedia({
		numFormulations => integer:number of formulations desired,
		problemDirectory => string:name of job directory,
		fbaStartParameters => {},
	});
	Output = {
		essentialNutrients => [string]:nutrient IDs,
		optionalNutrientSets => [[string]]:optional nutrient ID sets
	}
=item Description:
=cut
sub fbaCalculateMinimalMedia {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		numFormulations => 1,
		problemDirectory => undef,
		fbaStartParameters => {},
	});
	my $results = $self->runFBAStudy({
		fbaStartParameters => $args->{fbaStartParameters},
		setupParameters => {
			function => "setMinimalMediaStudy",
			arguments => {
				numFormulations=>$args->{numFormulations},
			} 
		},
		problemDirectory => $args->{problemDirectory},
		parameterFile => "MinimalMediaStudy.txt",
		startFresh => 1,
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem => 1,
		clearOuput => 1
	});
	return $results;
}
=head3 fbaSubmitGeneActivityAnalysis
=item Definition:
	$results = FIGMODELmodel->fbaSubmitGeneActivityAnalysis($arguments);
	$arguments = {media => opt string:media ID or "," delimited list of compounds,
				  geneCalls => {string:gene ID => double:call},
				  rxnKO => [string::reaction ids],
				  geneKO	 => [string::gene ids]}
	$results = {jobid => integer:job ID}
=item Description:
=cut
sub fbaSubmitGeneActivityAnalysis {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["geneCalls"],{user => undef,password => undef});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $fbaObj = $self->fba();
	return $fbaObj->setGeneActivityAnalysis($args);
}
=head3 fbaMultiplePhenotypeStudy
Definition:
	Output = FIGMODELmodel->fbaMultiplePhenotypeStudy({
		labels=>[string]:labels,
		mediaList=>[string]:media ID,
		KOlist=>[[string]]:reaction or gene id for ko
		problemDirectory => string,
		fbaStartParameters => {},
		findTightBounds => 0/1,
		deleteNoncontributingRxn => 0/1,
		identifyCriticalBiomassCpd => 0/1
	});
	Output = {
		string:labels=>{
			label=>string:label,
			media=>string:media,
			rxnKO=>[string]:rxnKO,
			geneKO=>[string]:geneKO,
			wildType=>double:growth,
			growth=>double:growth,
			fraction=>double:fraction of growth,
			noGrowthCompounds=>[string]:no growth compound list,
			dependantReactions=>[string]:list of reactions inactivated by knockout
		}
	}
Description:
=cut
sub fbaMultiplePhenotypeStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["labels","mediaList"],{
		koList => undef,
		problemDirectory => undef,
		fbaStartParameters => {},
		findTightBounds => 0,
		deleteNoncontributingRxn => 0,
		identifyCriticalBiomassCpd => 0 
	});
	if (!defined($args->{koList})) {
		for (my $i=0; $i < @{$args->{labels}}; $i++) {
			push(@{$args->{koList}},[]);
		}
	}
	if ($args->{findTightBounds} == 1) {
		$args->{fbaStartParameters}->{parameters}->{"find tight bounds"} = 1;
	}
	if ($args->{deleteNoncontributingRxn} == 1) {
		$args->{fbaStartParameters}->{parameters}->{"delete noncontributing reactions"} = 1;
	}
	if ($args->{identifyCriticalBiomassCpd} == 1) {
		$args->{fbaStartParameters}->{parameters}->{"optimize metabolite production if objective is zero"} = 1;
	}
	my $results = $self->runFBAStudy({
		fbaStartParameters => $args->{fbaStartParameters},
		setupParameters => {
			function => "setMultiPhenotypeStudy",
			arguments => {
				mediaList=>$args->{mediaList},
				labels=>$args->{labels},
				KOlist=>$args->{koList},
			} 
		},
		problemDirectory => $args->{problemDirectory},
		parameterFile => "MultiPhenotypeStudy.txt",
		startFresh => 1,
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem => 1,
		clearOuput => 1
	});
	return $results;
}
=head3 fbaTestGapfillingSolution
Definition:
	{}:Output = FIGMODELmodel->fbaTestGapfillingSolution({
		fbaStartParameters => undef,
		problemDirectory => undef
	});
Description:
=cut
sub fbaTestGapfillingSolution {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		fbaStartParameters => undef,
		problemDirectory => undef
	});
	if (defined($args->{error})) {return $self->error_message({function=>"fbaTestGapfillingSolution",args=>$args});}
	if (!defined($args->{fbaStartParameters}->{drnRxn})) {
		$args->{fbaStartParameters}->{drnRxn} = ["bio00001"];
	}
	my ($media,$label,$list);
	my $idhash;
	my $rxnmdls = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL=>$self->id()});
	for (my $i=0; $i < @{$rxnmdls}; $i++) {
		if ($rxnmdls->[$i]->pegs()  =~ m/GAP|AUTOCOMPLETION/) {
			$idhash->{$rxnmdls->[$i]->REACTION()} = $rxnmdls->[$i];
			push(@{$media},"NONE");
			push(@{$list},[$rxnmdls->[$i]->REACTION()]);
			push(@{$label},$rxnmdls->[$i]->REACTION());
		}
	}
	$args->{fbaStartParameters}->{parameters}->{"find tight bounds"} = 1;
	$args->{fbaStartParameters}->{parameters}->{"delete noncontributing reactions"} = 1;
	$args->{fbaStartParameters}->{parameters}->{"optimize metabolite production if objective is zero"} = 1;
	my $results = $self->runFBAStudy({
		fbaStartParameters => $args->{fbaStartParameters},
		setupParameters => {
			function => "setMultiPhenotypeStudy",
			arguments => {
				mediaList=>$media,
				labels=>$label,
				KOlist=>$list,
			}	
		},
		problemDirectory => $args->{problemDirectory},
		parameterFile => "GapfillingTest.txt",
		startFresh => 1,
		removeGapfillingFromModel => 0,
		forcePrintModel => 1,
		runProblem=>1
	});
	#Printing the results as notes in the model file
	my $deletionList;
	my $repRow;
	foreach my $lbl (keys(%{$results})) {
		if (defined($idhash->{$lbl})) {
			$repRow = $idhash->{$lbl};
			my $startNote = $idhash->{$lbl}->notes();
			if (!defined($startNote) || $startNote eq "NONE") {
				$startNote = "";	
			}
			$startNote =~ s/Autocompletion\sanalysis\([^\)]+\)//;
			if (length($startNote) > 0) {
				$startNote .= "|";	
			}
			if (defined($results->{$lbl}->{noGrowthCompounds}->[0]) && $results->{$lbl}->{noGrowthCompounds}->[0] ne "NA") {
				print "Nogrowth:".$lbl."\n";
				$startNote .= "Autocompletion analysis(Required to produce ".join(",",@{$results->{$lbl}->{noGrowthCompounds}}).")";
			}
			if (defined($results->{$lbl}->{dependantReactions}->[0]) && length($results->{$lbl}->{dependantReactions}->[0]) > 0) {
				if ($results->{$lbl}->{dependantReactions}->[0]	eq "DELETED") {
					print "Deleting:".$lbl."\n";
					$startNote .= "Autocompletion analysis(DELETE)";
				} else {
					print "Sensitive:".$lbl."\n";
					$startNote .= "Autocompletion analysis(Required to activate:".join(",",@{$results->{$lbl}->{dependantReactions}}).")";
				}
			}
			if (length($startNote) == 0) {
				$startNote = "NONE";	
			}
			$idhash->{$lbl}->notes($startNote);
		}
	}
	return $results;
}
=head3 fbaBiomassPrecursorDependancy
Definition:
	{}:Output = FIGMODELmodel->fbaBiomassPrecursorDependancy({});
	Output = {
		string:labels=>{
			label=>string:label,
			media=>string:media,
			rxnKO=>[string]:rxnKO,
			geneKO=>[string]:geneKO,
			wildType=>double:growth,
			growth=>double:growth,
			fraction=>double:fraction of growth,
			noGrowthCompounds=>[string]:no growth compound list
		}
	}
Description:
=cut
sub fbaBiomassPrecursorDependancy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{media=>$self->autocompleteMedia()});
	if (defined($args->{error})) {return $self->error_message({function=>"fbaBiomassPrecursorDependancy",args=>$args});}
	my ($media,$label,$list);
	my $rxnTbl = $self->reaction_table(1);
	$rxnTbl->add_headings(("NOTES"));
	my $idhash;
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		my $row = $rxnTbl->get_row($i);
		if (defined($row->{"ASSOCIATED PEG"}) && $row->{"ASSOCIATED PEG"}->[0] =~ m/GAP|AUTOCOMPLETION/ ) {
			$idhash->{$row->{"LOAD"}->[0]} = $row;
			push(@{$media},$args->{media});
			push(@{$list},[$row->{"LOAD"}->[0]]);
			push(@{$label},$row->{"LOAD"}->[0]);
		}
	}
	my $results = $self->fbaMultiplePhenotypeStudy({mediaList=>$media,labels=>$label,KOlist=>$list,checkMetaboliteWhenZeroGrowth=>1});	
	#Printing the results as notes in the model file
	foreach my $lbl (keys(%{$results})) {
		if (defined($results->{$lbl}->{noGrowthCompounds}->[0])) {
			$idhash->{$lbl}->{"NOTES"}->[0] = "Required to produce:".join(",",@{$results->{$lbl}->{noGrowthCompounds}});
		}
	}
	#Saving the model to file
	$rxnTbl->save();
	return {};
}

=head2 Database Integration Methods
=head3 check_for_role_changes
Definition:
	{changed=>{string:mapped role=>{string:gene role=>{string:reaction=>{string:gene=>1}}}},new=>{string:role=>{string:reaction=>{string:gene=>1}}}}
	= FIGMODELmodel->check_for_role_changes(
	{changed=>{string:mapped role=>{string:gene role=>{string:reaction=>{string:gene=>1}}}},new=>{string:role=>{string:reaction=>{string:gene=>1}}}});
=cut

sub check_for_role_changes {
	my ($self,$roleChangeHash,$roleGeneHash) = @_;
	#Getting reaction table
	my $ftrTbl = $self->feature_table();
	if (defined($ftrTbl)) {
		for (my $i=0; $i < $ftrTbl->size(); $i++) {
			my $row = $ftrTbl->get_row($i);
			my $rxnHash;
			for (my $j=0; $j < @{$row->{ROLES}}; $j++) {
				$roleGeneHash->{$row->{ROLES}->[$j]}->{$row->{ID}->[0]} = 1;
				my $rxns = $self->figmodel()->mapping()->get_role_rxns($row->{ROLES}->[$j]);
				if (defined($rxns)) {
					for (my $k=0; $k < @{$rxns}; $k++) {
						$rxnHash->{$rxns->[$k]} = 1;
					}
				}
			}
			#Checking if new reactions will appear
			my @rxnKeys = keys(%{$rxnHash});
			for (my $k=0; $k < @rxnKeys; $k++) {
				my $match = 0;
				for (my $j=0; $j < @{$row->{$self->id()."REACTIONS"}}; $j++) {
					if ($rxnKeys[$k] eq $row->{$self->id()."REACTIONS"}->[$j]) {
						$match = 1;
						last;	
					}
				}
				if ($match == 0) {
					my $roles = $self->figmodel()->mapping()->get_rxn_roles($rxnKeys[$k]);
					if (defined($roles)) {
						for (my $j=0; $j < @{$roles}; $j++) {
							for (my $m=0; $m < @{$row->{ROLES}}; $m++) {
								if ($roles->[$j] eq $row->{ROLES}->[$m]) {
									$roleChangeHash->{new}->{$roles->[$j]}->{reactions}->{$rxnKeys[$k]} = 1;
									$roleChangeHash->{new}->{$roles->[$j]}->{genes}->{$row->{ID}->[0]} = 1;
									last;
								}
							}
						}
					}
				}
			}
			#Checking if the gene is mapped to reactions that it should not be mapped to (according to current mappings)
			for (my $j=0; $j < @{$row->{$self->id()."REACTIONS"}}; $j++) {
				my $match = 0;
				my @rxnKeys = keys(%{$rxnHash});
				for (my $k=0; $k < @rxnKeys; $k++) {
					if ($rxnKeys[$k] eq $row->{$self->id()."REACTIONS"}->[$j]) {
						$match = 1;
						last;	
					}
				}
				if ($match == 0) {
					my $roles = $self->figmodel()->mapping()->get_rxn_roles($row->{$self->id()."REACTIONS"}->[$j]);
					if (defined($roles)) {
						for (my $k=0; $k < @{$roles}; $k++) {
							for (my $m=0; $m < @{$row->{ROLES}}; $m++) {
								$roleChangeHash->{changed}->{$roles->[$k]}->{$row->{ROLES}->[$m]}->{reactions}->{$row->{$self->id()."REACTIONS"}->[$j]} = 1;
								$roleChangeHash->{changed}->{$roles->[$k]}->{$row->{ROLES}->[$m]}->{genes}->{$row->{ID}->[0]} = 1;
							}
						}
					}
				}
			}
		}
	}
	return ($roleChangeHash,$roleGeneHash);
}

=head3 build_default_model_config 
Generates a FIGMODELConfig hash based on the contents of the model
directory.
=cut
sub build_default_model_config {
	my ($self) = @_;
	my $directory = $self->directory();
	my $config = {};
	if((-f $directory.'rxnmdl.txt') && ($self->version() ne $self->ppo_version())) {
		$config->{'PPO_tbl_rxnmdl'} = {
			name => [$directory."rxnmdl.txt"],
			delimiter => [";"],
			itemDelimiter => ["|"],
			headings => ["REACTION", "MODEL", "compartment", "directionality",
				"pegs", "confidence", "notes", "reference", "subsystem"],
			headingLine => 0,
			hashColumns => ["MODEL", "REACTION"],
			status => [1],
			type => ['FIGMODELTable'],
		}; 
	
	}
	if(-d $directory.'biochemistry') {
		if (-f $directory.'biochemistry/reaction.txt') {
			$config->{'PPO_tbl_reaction'} = { 
				name  => [$directory.'biochemistry/reaction.txt'],
				delimiter => ["\t"],
				headings => ["id","name","abbrev","enzyme","code",
					"equation","definition","deltaG","deltaGErr","structuralCues",
					"reversibility","thermoReversibility","owner","scope",
					"modificationDate","creationDate","public","status",
					"abstractReaction","transportedAtoms"],
				itemDelimiter => [";"],
				headingLine => 0,
				hashColumns => ["id","name","abbrev","enzyme","code","equation","owner","scope","public","abstractReaction"],
				status => [1],
				type => ['FIGMODELTable']
			};
		}
		if (-f $directory.'biochemistry/compound.txt') {
			$config->{'PPO_tbl_compound'} = {
				name  => [$directory.'biochemistry/compound.txt'],
				delimiter => ["\t"],
				headings => ["id","name","abbrev","formula","mass",
					"charge","deltaG","deltaGErr","structuralCues",
					"stringcode","pKa","pKb","owner","scope",
					"modificationDate","creationDate","public",
					"abstractCompound"],
				itemDelimiter => [";"],
				headingLine => 0,
				hashColumns => ["id","name","abbrev","formula","stringcode","owner","scope","public",
					"abstractCompound"],
				status => [1],
				type => ['FIGMODELTable'],
			};
		}
		if (-f $directory.'biochemistry/cpdals.txt') {
			$config->{'PPO_tbl_cpdals'} = {
				name  => [$directory.'biochemistry/cpdals.txt'],
				delimiter => ["\t"],
				headings => ["COMPOUND","alias","type"],
				itemDelimiter => [";"],
				headingLine => 0,
				hashColumns => ["COMPOUND","alias","type"],
				status => [1],
				type => ['FIGMODELTable'],
			};
		}
		if (-f $directory.'biochemistry/rxnals.txt') {
			$config->{'PPO_tbl_rxnals'} = {
				name  => [$directory.'biochemistry/rxnals.txt'],
				delimiter => ["\t"],
				headings => ["REACTION","alias","type"],
				itemDelimiter => [";"],
				headingLine => 0,
				hashColumns => ["REACTION","alias","type"],
				status => [1],
				type => ['FIGMODELTable'],
			};
		}
	}
	if(-d $directory.'mappings' ) {
		# TODO mappings objects
	}
	if(-d $directory.'annotations' ) {
		# TODO annotation objects
	}
	return $config;
}
			
=head3 run_default_model_predictions
REPLACED BY fbaDefaultStudies:MARKED FOR DELETION
=cut
sub run_default_model_predictions {
	my ($self,$Media) = @_;
	my $out = $self->fbaDefaultStudies({media => $Media});
	return $self->figmodel()->success();
}
=head3 calculate_growth
REPLACED BY fbaCalculateGrowth:MARKED FOR DELETION
=cut
sub calculate_growth {
	my ($self,$Media,$outputDirectory,$InParameters,$saveLPFile) = @_;
	my $result = $self->fbaCalculateGrowth({media => $Media,outputDirectory => $outputDirectory,parameters => $InParameters,saveLPfile => $saveLPFile});
	if (defined($result->{growth}) && $result->{growth} > 0) {
		return $result->{growth};
	} else {
		return "NOGROWTH:".$result->{noGrowthCompounds};
	}
	return "";
}
=head3 IdentifyDependancyOfGapFillingReactions
REPLACED BY fbaBiomassPrecursorDependancy:MARKED FOR DELETION
=cut
sub IdentifyDependancyOfGapFillingReactions {
	my ($self,$media) = @_;
	return $self->fbaBiomassPrecursorDependancy({media=>$media});
}
=head3 remove_reaction
REPLACED BY removeReactions:MARKED FOR DELETION (new function conforms with our new coding style and allows simultaneous deletion of multiple reactions)
=cut
sub remove_reaction {
	my ($self, $rxnId, $compartment) = @_;
	my $result = $self->removeReactions({ids=>[$rxnId],compartments=>[$compartment],reason=>"Model controls",user=>$self->owner(),trackChanges=>1});
	if (defined($result->{error})) {
		return $self->error_message({function => "remove_reaction",message => $result->{error}});
	}
	return {};
}

1;
