use strict;
package ModelSEED::FIGMODEL::FIGMODELrole;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELrole object
=head2 Introduction
Module for holding functional role related functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELrole = FIGMODELrole->new({figmodel => FIGMODEL:parent figmodel object,id => string:role id});
Description:
	This is the constructor for the FIGMODELrole object.
=cut
sub new {
	my ($class,$args) = @_;
	#Must manualy check for figmodel argument since figmodel is needed for automated checking
	if (!defined($args->{figmodel})) {
		print STDERR "FIGMODELreaction->new():figmodel must be defined to create an genome object!\n";
		return undef;
	}
	my $self = {_figmodel => $args->{figmodel}};
    weaken($self->{_figmodel});
	bless $self;
	if (defined($args->{id})) {
		$self->{_id} = $args->{id};
		if ($self->{_id} =~ m/^fr\d+$/) {
			my $roles = $self->figmodel()->database()->get_object_hash({
				type => "role",
				attribute => "id",
				useCache => 1
			});
			if (!defined($roles->{$self->{_id}})) {
				$self->error_message({message=>"Could not find role in database:".$args->{id}});
				return undef;
			}
			$self->{_ppo} = $roles->{$self->{_id}}->[0];
		} else {
			my $roles = $self->figmodel()->database()->get_object_hash({
				type => "role",
				attribute => "searchname",
				useCache => 1
			});
			my $searchName = $self->convert_to_search_role({name => $self->{_id}});
			if (!defined($roles->{$searchName})) {
				$self->error_message({message=>"Could not find role in database:".$args->{id}});
				return undef;
			}
			$self->{_ppo} = $roles->{$searchName}->[0];
			$self->{_id} = $self->{_ppo}->id();
		}
	}
	return $self;
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELrole->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}
=head3 ppo
Definition:
	PPO:genomestats = FIGMODELrole->ppo();
Description:
	Returns the PPO genomestats object for the role
=cut
sub ppo {
	my ($self) = @_;
	return $self->{_ppo};
}
=head3 id
Definition:
	string = FIGMODELrole->id();
Description:
=cut
sub id {
	my ($self) = @_;
	return $self->{_id};
}
=head3 error_message
Definition:
	{}:Output = FIGMODELrole->error_message({
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
	$args->{"package"} = "FIGMODELrole";
    return $self->figmodel()->new_error_message($args);
}
=head3 roles_of_function
Definition:
	[string]:roles = FIGMODELrole->roles_of_function({
		function => string,
		output => name/search/id
	});
Description:
=cut
sub roles_of_function {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["function"],{
		output => "name"
	});
	return $self->error_message({function => "roles_of_function",args=>$args}) if (defined($args->{error}));
	my %RoleHash;
	my @Roles = split(/\s*;\s+|\s+[\@\/]\s+/g,$args->{function});
	foreach my $Role (@Roles) {
		$Role =~ s/\s*\#.*$//;
		if ($args->{output} eq "search" || $args->{output} eq "id") {
			$Role = $self->convert_to_search_role({name => $Role});
			if ($args->{output} eq "id") {
				 my $roleObj = $self->figmodel()->database()->get_object("role",{searchname => $Role});
				if (defined($roleObj)) {
					$Role = $roleObj->id();	
				} else {
					$Role = undef;	
				}
			}
		}
		if (defined($Role)) {
			$RoleHash{$Role} = 1;
		}
	}
	return [sort keys(%RoleHash)];
}
=head3 convert_to_search_role
Definition:
	string = FIGMODELrole->convert_to_search_role({name => string});
Description:
=cut
sub convert_to_search_role {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["name"],{});
	return $self->error_message({function => "convert_to_search_role",args=>$args}) if (defined($args->{error}));
	my $searchname = lc($args->{name});
	$searchname =~ s/\d+\.\d+\.\d+\.[-0123456789]+//g;
	$searchname =~ s/\s//g;
	return $searchname;
}
=head3 role_is_valid
Definition:
	0/1 = FIGMODELrole->role_is_valid({name => string});
=cut
sub role_is_valid {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["name"],{});
	if ($args->{name} =~ m/hypothetical\sprotein/i || $args->{name} =~ m/unknown/i || $args->{name} eq "Bacteriophage" || $args->{name} eq "putative" || $args->{name} eq "Doubtful CDS") {
		return 0;
	}
	return 1;
}
=head3 subsystems_of_role
Definition:
	[PPOsubsytem] = FIGMODELrole->subsystems_of_role();
Description:
=cut
sub subsystems_of_role {
	my ($self) = @_;
	if (!defined($self->{_subsys})) {
		$self->{_subsys} = [];
		my $subsysRoles = $self->figmodel()->database()->get_object_hash({
			type => "ssroles",
			attribute => "ROLE",
			useCache => 1
		});
		if (defined($subsysRoles->{$self->ppo()->id()})) {
			my $subsys = $self->figmodel()->database()->get_object_hash({
				type => "subsystem",
				attribute => "id",
				parameters => {status => "core"},
				useCache => 1
			});
			for (my $i=0; $i < @{$subsysRoles->{$self->ppo()->id()}}; $i++) {
				if (defined($subsys->{$subsysRoles->{$self->ppo()->id()}->[$i]->SUBSYSTEM()})) {
					push(@{$self->{_subsys}},@{$subsys->{$subsysRoles->{$self->ppo()->id()}->[$i]->SUBSYSTEM()}});
				}
			}
		}
	}
	return $self->{_subsys};
}

1;
