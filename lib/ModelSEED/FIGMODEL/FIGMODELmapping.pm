use strict;
package ModelSEED::FIGMODEL::FIGMODELmapping;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELmapping object
=head2 Introduction
Module for holding functions to manipulate mappings between functional roles and reactions in Model SEED
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELmapping = FIGMODELmapping->new(figmodel);
Description:
	This is the constructor for the FIGMODELmapping object.
=cut
sub new {
	my ($class,$figmodel) = @_;
	#Error checking first
	if (!defined($figmodel)) {
		print STDERR "FIGMODELmapping->new():figmodel must be defined to create a mapping object!\n";
		return undef;
	}
	my $self = {_figmodel => $figmodel };
    weaken($self->{_figmodel});
	bless $self;
	return $self;
}

=head3 new
Definition:
	FIGMODELmapping = FIGMODELmapping->new();
Description:
	This is the constructor for the FIGMODELmapping object.
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 error_message
Definition:
	{}:Output = FIGMODELmapping->error_message({
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
sub error_message {
	my ($self,$args) = @_;
	$args->{"package"} = "FIGMODELmapping";
    return $self->figmodel()->new_error_message($args);
}

=head3 create_new_mapping
Definition:
	string:error message = FIGMODELmapping->create_new_mapping([string]:role names,[string]:role types global/local,[string]:reaction);
Description:
	This function creates or obtains the complex corresponding to the input role list and maps the complex to the input reaction list.
=cut
sub create_new_mapping {
	my ($self,$roles,$roleTypes,$reactions) = @_;
	#Inspecting input
	if (!defined($roles) || !defined($roleTypes) || !defined($reactions)) {
    	return "FIGMODELmapping:need to supply roles, types, and reactions to create a mapping";
    }
    #Getting or creating a complex
	my $complex = $self->get_complex($roles,$roleTypes,1);
	#Getting the reactions already mapped to the complex
	my $objs = $self->figmodel()->database()->get_objects("rxncpx",{COMPLEX=>$complex->id()});
	#Mapping the complex to the reactions
	for (my $i=0; $i < @{$reactions}; $i++) {
		my $obj;
		for (my $j=0; $j < @{$objs};$j++) {
			if ($objs->[$j]->REACTION() eq $reactions->[$i]) {
				$obj = $objs->[$j];
				last;
			}
		}
		if (!defined($obj)) {
			$self->figmodel()->database()->create_object("rxncpx",{REACTION=>$reactions->[$i],COMPLEX=>$complex->id(),master=>1});
		} else {
			$obj->master(1);	
		}
	}
	return undef;
}

=head3 get_complex
Definition:
	FIGMODELmapping = FIGMODELmapping->get_complex([string]:role names,[string]:role types global/local,0/1:indicates if new complex should be created);
Description:
	This function creates or obtains the complex corresponding to the input role list and maps the complex to the input reaction list.
=cut
sub get_complex {
	my ($self,$roles,$roleTypes,$creation) = @_;
	#Translating roles into role IDs
	my $roleIDs;
	my $typeHash;
	for (my $i=0; $i < @{$roles}; $i++) {
		my $roleObj = $self->get_role($roles->[$i],1);
		$typeHash->{$roleObj->id()} = $roleTypes->[$i];
		push(@{$roleIDs},$roleObj->id());
	}
	#Creating key for complex
	my $key = join("|",sort(@{$roleIDs}));
	if (!defined($self->complex_hash()->{$key}) && defined($creation) && $creation == 1) {
		#Creating the complex object
		my $newID = $self->figmodel()->check_out_new_id("complex");
		$self->complex_hash()->{$key} = $self->figmodel()->database()->create_object("complex",{id=>$newID});
		#Creating the role complex mapping
		
	} elsif (defined($self->complex_hash()->{$key})) {
		for (my $i=0; $i < @{$roleIDs}; $i++) {
			my $obj = $self->figmodel()->database()->get_object("cpxrole",{ROLE=>$roleIDs->[$i],COMPLEX=>$self->complex_hash()->{$key}->id()});
			if (defined($obj)) {
				if ($roleTypes->[$i] eq "Global") {
					$obj->type("G");
				} else {
					
				}$obj->type("L");
			}
		}
	}
	return $self->complex_hash()->{$key};
}

=head3 get_role
Definition:
	PPOrole = FIGMODELmapping->get_role(string:role names,0/1:indicates if new role should be created);
Description:
	This function creates or obtains the role corresponding to the input role name
=cut
sub get_role {
	my ($self,$role,$creation) = @_;
	my $sname = $self->convert_to_search_role($role);
	my $obj = $self->figmodel()->database()->get_object("role",{searchname=>$sname});
	if (!defined($obj) && defined($creation) && $creation == 1) {
		my $newID = $self->figmodel()->check_out_new_id("role");
		$obj = $self->figmodel()->database()->create_object("rxncpx",{id=>$newID,name=>$role,searchname=>$sname});
	}
	return $obj;
}

=head3 convert_to_search_role
Definition:
	string::search role = FIGMODELmapping->convert_to_search_role(string::role name);
=cut
sub convert_to_search_role {
	my ($self,$inRole) = @_;
	my $searchname = lc($inRole);
	$searchname =~ s/\d+\.\d+\.\d+\.[-0123456789]+//g;
	$searchname =~ s/\s//g;
	return $searchname;
}

=head3 check_for_role_changes
Definition:
	FIGMODELmapping->check_for_role_changes();
=cut
sub check_for_role_changes {
	my ($self) = @_;
	my $mdls = $self->figmodel()->database()->get_objects("model",{public=>1});
	my ($roleChangeHash,$roleGeneHash);
	my $mdlCount = @{$mdls};
	for (my $i=0; $i < @{$mdls}; $i++) {
		if ($mdls->[$i]->id() =~ m/Seed/) {
			print $mdls->[$i]->id().":".$i." out of ".$mdlCount."\n";
			my $mdlObj = $self->figmodel()->get_model($mdls->[$i]->id());
			($roleChangeHash,$roleGeneHash) = $mdlObj->check_for_role_changes($roleChangeHash,$roleGeneHash);
		}
		if ($i == 0 || $i % 50 == 0) {
			$self->print_changes($roleGeneHash,$roleChangeHash);
		}
	}
	$self->print_changes($roleGeneHash,$roleChangeHash);
}

sub print_changes {
	my ($self,$roleGeneHash,$roleChangeHash) = @_;
	my $output = ["Mapped role\tMapped reactions\tMap count\tAnnotated role\tMapped reactions\tAnno count\tReactions\tGene count\tGenes"];
	my @mapRoles = keys(%{$roleChangeHash->{changed}});
	for (my $i=0; $i < @mapRoles; $i++) {
		my $roleGeneCount = 0;
		if (defined($roleGeneHash->{$mapRoles[$i]})) {
			$roleGeneCount = keys(%{$roleGeneHash->{$mapRoles[$i]}});
		}
		my $reactions = "NONE";
		my $rxnList = $self->get_role_rxns($mapRoles[$i]);
		if (defined($rxnList)){
			$reactions = join(";",@{$rxnList});	
		}
		my $line = $mapRoles[$i]."\t".$reactions."\t".$roleGeneCount."\t";
		my @modelRoles = keys(%{$roleChangeHash->{changed}->{$mapRoles[$i]}});
		for (my $j=0; $j < @modelRoles; $j++) {
			my $roleGeneCount = 0;
			if (defined($roleGeneHash->{$modelRoles[$j]})) {
				$roleGeneCount = keys(%{$roleGeneHash->{$modelRoles[$j]}});
			}
			$reactions = "NONE";
			$rxnList = $self->get_role_rxns($modelRoles[$j]);
			if (defined($rxnList)){
				$reactions = join(";",@{$rxnList});	
			}
			my $geneCount = keys(%{$roleChangeHash->{changed}->{$mapRoles[$i]}->{$modelRoles[$j]}->{genes}});
			my $newLine = $line.$modelRoles[$j]."\t".$reactions."\t".$roleGeneCount."\t".join(";",keys(%{$roleChangeHash->{changed}->{$mapRoles[$i]}->{$modelRoles[$j]}->{reactions}}))."\t".$geneCount."\t".join(";",keys(%{$roleChangeHash->{changed}->{$mapRoles[$i]}->{$modelRoles[$j]}->{genes}}));
			push(@{$output},$newLine);
		}
	}
	$self->figmodel()->database()->print_array_to_file("/home/chenry/MappingChanges.txt",$output);
}

=head3 get_role_rxns
Definition:
	[string]:reaction ids = FIGMODELmapping->get_role_rxns(string:role);
=cut
sub get_role_rxns {
	my ($self,$role) = @_;
	my $roleObj = $self->get_role($role);
	if (!defined($roleObj)) {
		return undef;	
	}
	my $cpxObjs = $self->figmodel()->database()->get_objects("cpxrole",{ROLE=>$roleObj->id()});
	my $rxnHash;
	for (my $i=0; $i < @{$cpxObjs}; $i++) {
		if ($cpxObjs->[$i]->type() ne "N") {
			my $rxnObjs = $self->figmodel()->database()->get_objects("rxncpx",{COMPLEX=>$cpxObjs->[$i]->COMPLEX(),master=>1});
			for (my $j=0; $j < @{$rxnObjs}; $j++) {
				$rxnHash->{$rxnObjs->[$j]->REACTION()} = 1;
			}
		}
	}
	my $rxnList;
	push(@{$rxnList},keys(%{$rxnHash}));
	return $rxnList;
}

=head3 get_rxn_roles
Definition:
	[string]:role names = FIGMODELmapping->get_rxn_roles(string:reaction id);
=cut
sub get_rxn_roles {
	my ($self,$rxn) = @_;
	if (!defined($self->{_rxnroles}->{$rxn})) {
		$self->{_rxnroles}->{$rxn} = {};
		my $cpxObjs = $self->figmodel()->database()->get_objects("rxncpx",{REACTION=>$rxn,master=>1});
		my $roleHash;
		for (my $i=0; $i < @{$cpxObjs}; $i++) {
			my $roleObjs = $self->figmodel()->database()->get_objects("cpxrole",{COMPLEX=>$cpxObjs->[$i]->COMPLEX()});
			for (my $j=0; $j < @{$roleObjs}; $j++) {
				if ($roleObjs->[$j]->type() ne "N") {
					$roleHash->{$roleObjs->[$j]->ROLE()} = 1;
				}
			}
		}	
		my @roles = keys(%{$roleHash});
		for (my $i=0; $i < @roles; $i++) {
			my $roleObj = $self->figmodel()->database()->get_object("role",{id=>$roles[$i]});
			$self->{_rxnroles}->{$rxn}->{$roleObj->id()} = $roleObj->name();
		}
	}
	my $list;
	foreach my $role (keys(%{$self->{_rxnroles}->{$rxn}})) {
		push(@{$list},$self->{_rxnroles}->{$rxn}->{$role});
	}	
	return $list;
}

=head3 get_rxn_subsys
Definition:
	[string]:subsystem names = FIGMODELmapping->get_rxn_subsys(string:reaction id);
=cut
sub get_rxn_subsys {
	my ($self,$rxn) = @_;
	if (!defined($self->{_rxnsubsys}->{$rxn})) {
		if (!defined($self->{_rxnroles}->{$rxn})) {
			$self->get_rxn_roles($rxn);
		}
		my @roles = keys(%{$self->{_rxnroles}->{$rxn}});
		my $subsysHash;
		for (my $i=0; $i < @roles; $i++) {
			my $subsysObjs = $self->figmodel()->database()->get_objects("ssroles",{ROLE=>$roles[$i]});
			for (my $j=0; $j < @{$subsysObjs}; $j++) {
				$subsysHash->{$subsysObjs->[$j]->SUBSYSTEM()} = 1;
			}
		}
		foreach my $subsys (keys(%{$subsysHash})) {
			my $subsysObj = $self->figmodel()->database()->get_object("subsystem",{status => "core",id=>$subsys});
			if (defined($subsysObj)) {
				$self->{_rxnsubsys}->{$rxn}->{$subsysObj->id()} = $subsysObj->name();
			}
		}
	}
	my $list;
	foreach my $ss (keys(%{$self->{_rxnsubsys}->{$rxn}})) {
		push(@{$list},$self->{_rxnsubsys}->{$rxn}->{$ss});
	}
	return $list;
}

=head3 get_role_rxn_hash
Definition:
	{string:reaction ids => {string:role IDs => PPOrole}} = FIGMODELmapping->get_role_rxn_hash();
=cut
sub get_role_rxn_hash {
	my ($self) = @_;
	if (!defined($self->{_rolerxnhash})) {
		my $cpxObjs = $self->figmodel()->database()->get_objects("rxncpx",{master=>1});
		my $roleObjs = $self->figmodel()->database()->get_objects("cpxrole");
		my $roleNameObjs = $self->figmodel()->database()->get_objects("role");
		my $roleNameHash;
		for (my $i=0; $i < @{$roleNameObjs}; $i++) {
			$roleNameHash->{$roleNameObjs->[$i]->id()} = $roleNameObjs->[$i];
		}
		my $roleComplexHash;
		for (my $i=0; $i < @{$roleObjs}; $i++) {
			$roleComplexHash->{$roleObjs->[$i]->COMPLEX()}->{$roleObjs->[$i]->ROLE()} = $roleNameHash->{$roleObjs->[$i]->ROLE()};
		}
		for (my $i=0; $i < @{$cpxObjs}; $i++) {
			if (defined($roleComplexHash->{$cpxObjs->[$i]->COMPLEX()})) {
				foreach my $roleID (keys(%{$roleComplexHash->{$cpxObjs->[$i]->COMPLEX()}})) {
					$self->{_rolerxnhash}->{$cpxObjs->[$i]->REACTION()}->{$roleID} = $roleComplexHash->{$cpxObjs->[$i]->COMPLEX()}->{$roleID};
				}
			}
		}
	}
	return $self->{_rolerxnhash};
}

=head3 roles
Definition:
	[string]:role names = FIGMODELmapping->roles();
=cut
sub roles {
	my ($self) = @_;
	my $hash = $self->get_role_rxn_hash();
	my $roleHash;
	foreach my $rxn (keys(%{$hash})) {
		foreach my $role (keys(%{$hash->{$rxn}})) {
			$roleHash->{$hash->{$rxn}->{$role}->name()} = 1;
		}
	}
	my $list;
	push(@{$list},keys(%{$roleHash}));
	return $list;
}

=head3 get_subsy_rxn_hash
Definition:
	{string:reaction ids => {string:role IDs => PPOrole}} = FIGMODELmapping->get_subsy_rxn_hash();
=cut
sub get_subsy_rxn_hash {
	my ($self,$rxn) = @_;
	if (!defined($self->{_subsysrxnhash})) {
		my $roleHash = $self->get_role_rxn_hash();
		my $subsysroles = $self->figmodel()->database()->get_objects("ssroles");
		my $subsystems = $self->figmodel()->database()->get_objects("subsystem");
		my $subsysHash;
		for (my $i=0; $i < @{$subsystems}; $i++) {
			$subsysHash->{$subsystems->[$i]->id()} = $subsystems->[$i];
		}
		my $subsysRoleHash;
		for (my $i=0; $i < @{$subsysroles}; $i++) {
			$subsysRoleHash->{$subsysroles->[$i]->ROLE()}->{$subsysroles->[$i]->SUBSYSTEM()} = $subsysHash->{$subsysroles->[$i]->SUBSYSTEM()};
		}
		my $roleObjs = $self->figmodel()->database()->get_objects("cpxrole");
		foreach my $rxn (keys(%{$roleHash})) {
			foreach my $role (keys(%{$roleHash->{$rxn}})) {
				$self->{_subsysrxnhash}->{$rxn} = $subsysRoleHash->{$role};
				foreach my $subsys (keys(%{$subsysRoleHash->{$role}})) {
					$self->{_subsysrolerxnhash}->{$rxn}->{$subsys}->{$role} = 1;
				}
			}
		}
	}
	return $self->{_subsysrxnhash};
}

=head3 metabolic_neighborhood_of_roles
=item Definition:
	{} = FBAMODEL->get_metabolically_neighboring_roles->({role => string:role name})
	Output : {string:metabolite IDs => [string]:neighboring functional roles based on this metabolite}
=item Description:	
	Identifies the functional roles associated with reactions that neighbor the input functional role.
	Output is organized by the metabolite linking the two roles together.
=cut
sub metabolic_neighborhood_of_roles {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["roles"]);
    if (defined($args->{error})) {return $self->error_message({args=>$args});}
	my $allRoleNeighbors;
	for (my $i=0; $i < @{$args->{roles}}; $i++) {
	    #Checking if role exists in the database
	    my $role = $self->figmodel()->get_role($args->{roles}->[$i]);
	    if (!defined($role)) {return $self->error_message({message=>"metabolic_neighborhood_of_roles:could not find role",args=>$args});}
	    #Getting reactions for role
	    my $rxns = $self->get_role_rxns($role->name());
	    if (!defined($rxns)) {return {};}
	    #Getting neighboring rxns
	    my $allRxnNeighbors;
	    for (my $i=0; $i < @{$rxns}; $i++) {
	    	my $rxnObj = $self->figmodel()->get_reaction($rxns->[$i]);
	    	if (defined($rxnObj)) {
	    		my $rxnNeighbors = $rxnObj->get_neighboring_reactions({});
	    		foreach my $cpdID (keys(%{$rxnNeighbors})) {
	    			push(@{$allRxnNeighbors->{$cpdID}},@{$rxnNeighbors->{$cpdID}});
	    		}
	    	}
	    }
	    #Translating neighboring rxns to neighboring roles
	    foreach my $cpdID (keys(%{$allRxnNeighbors})) {
	    	my $roleHash;
	    	for (my $i=0; $i < @{$allRxnNeighbors->{$cpdID}}; $i++) {
	    		my $roles = $self->get_rxn_roles($allRxnNeighbors->{$cpdID}->[$i]);
	    		if (defined($roles)) {
		    		for (my $j=0; $j < @{$roles}; $j++) {
		    			$roleHash->{$roles->[$j]} = 1;
		    		}
	    		}
	    	}
	    	push(@{$allRoleNeighbors->{$role->name()}->{$cpdID}},keys(%{$roleHash}));
	    }
	}
    return $allRoleNeighbors;
}

=head3 print_role_cpx_rxn_table
=item Definition:
	{} = FBAMODEL->print_role_cpx_rxn_table->({filename => string})
=item Description:	
=cut
sub print_role_cpx_rxn_table {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
    return $self->error_message({args=>$args}) if (defined($args->{error}));
    my $cpxrxns = $self->figmodel()->database()->get_object_hash({
		type => "rxncpx",
		attribute => "COMPLEX",
		parameters => {master => 1},
		useCache => 1
	});
	my $cpxroles = $self->figmodel()->database()->get_object_hash({
		type => "cpxrole",
		attribute => "COMPLEX",
		useCache => 1
	});
    my $roles = $self->figmodel()->database()->get_object_hash({
		type => "role",
		attribute => "id",
		useCache => 1
	});
	my $roleHash;
	foreach my $cpx (keys(%{$cpxrxns})) {
		if (defined($cpxroles->{$cpx})) {
			for (my $i=0; $i < @{$cpxroles->{$cpx}}; $i++) {
				my $role = $cpxroles->{$cpx}->[$i]->ROLE();
				if (defined($roles->{$role})) {
					$roleHash->{$role}->{role} = $roles->{$role}->[0]->name();
					$roleHash->{$role}->{complexes}->{$cpxrxns->{$cpx}->[0]->COMPLEX} = 1;
					$roleHash->{$role}->{reactions}->{$cpxrxns->{$cpx}->[0]->REACTION} = 1;
				}
			}
		}
	}
	my $output = ["Roles\tComplexes\tReactions"];
	foreach my $role (keys(%{$roleHash})) {
		if (length($roleHash->{$role}->{role}) > 0) {
			my $line = $roleHash->{$role}->{role}."\t".join("|",keys(%{$roleHash->{$role}->{complexes}}))."\t".join("|",keys(%{$roleHash->{$role}->{reactions}}));
			push(@{$output},$line);
		} else {
			print $role."\n";
		}
	}
	$self->figmodel()->database()->print_array_to_file($args->{filename},$output);
}

1;
