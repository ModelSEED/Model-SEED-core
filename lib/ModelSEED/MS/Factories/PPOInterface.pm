########################################################################
# ModelSEED::MS::Factories - This is the factory for producing the moose objects from the SEED data
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::utilities;
use ModelSEED::MS::ObjectManager;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Utilities::GlobalFunctions;
use FIGMODEL;
package ModelSEED::MS::Factories::MappingFactory;
use Moose;


# ATTRIBUTES:
has username => ( is => 'rw', isa => 'Str', required => 1 );
has password => ( is => 'rw', isa => 'Str', required => 1 );
has figmodel => ( is => 'rw', isa => 'FIGMODEL', lazy => 1, builder => '_buildfigmodel' );
has om => ( is => 'rw', isa => 'ModelSEED::MS::ObjectManager', lazy => 1, builder => '_buildom' );


# BUILDERS:
sub _buildfigmodel {
	my ($self) = @_;
	return ModelSEED::FIGMODEL->new({username => $self->username(),password => $self->password()}); 
}
sub _buildom {
	my ($self) = @_;
	my $om = ModelSEED::MS::ObjectManager->new({
		db => ModelSEED::FileDB->new({directory => "C:/Code/Model-SEED-core/data/filedb/"}),
		username => $self->username(),
		password => $self->password(),
		selectedAliases => {
			ReactionAliasSet => "ModelSEED",
			CompoundAliasSet => "ModelSEED",
			ComplexAliasSet => "ModelSEED",
			RoleAliasSet => "ModelSEED",
			RolesetAliasSet => "ModelSEED"
		}
	});
	$om->authenticate($self->username(),$self->password());
	return $om; 
}

# FUNCTIONS:
sub createBiochemistry {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		name => $self->username()."/primary"
	});
	my $biochemistry = $self->om()->create("Biochemistry",{
		name=>$args->{name},
		public => 1,
		locked => 0
	});
	my $cpds = $self->figmodel()->database()->get_objects("compound");
	for (my $i=0; $i < @{$cpds}; $i++) {
		my $cpd = $biochemistry->create("Compound",{
			locked => "0",
			name => $cpds->[$i]->name(),
			abbreviation => $cpds->[$i]->abbrev(),
			unchargedFormula => $unchargedFormula,
			formula => $cpds->[$i]->formula()
			mass => $cpds->[$i]->mass()
			defaultCharge => $cpds->[$i]->charge()
			deltaG => $cpds->[$i]->deltaG()
			deltaGErr => $cpds->[$i]->deltaGErr()
		});
		
		
		<scalar label="id" type="CHAR(32)" mandatory="1" />
		<scalar label="name" type="CHAR(255)" mandatory="1" />
		<scalar label="abbrev" type="CHAR(255)" mandatory="1" />
		<scalar label="formula" type="CHAR(125)"/>
		<scalar label="mass" type="FLOAT"/>
		<scalar label="charge" type="FLOAT"/>
		<scalar label="deltaG" type="FLOAT"/>
		<scalar label="deltaGErr" type="FLOAT"/>
		<scalar label="structuralCues" type="TEXT"/>
		<scalar label="stringcode" type="TEXT"/>
		<scalar label="pKa" type="TEXT"/>
		<scalar label="pKb" type="TEXT"/>
		<scalar label="owner" type="CHAR(32)"/>
		<scalar label="scope" type="TEXT" default="all" />
		<scalar label="modificationDate" type="INTEGER" mandatory="1" />
		<scalar label="creationDate" type="INTEGER" mandatory="1" />
		<scalar label="public" type="INTEGER" default="1" />
		<scalar label="abstractCompound" type="CHAR(32)" />
		<unique_index><attribute label="id"/></unique_index>
		<index><attribute label="name"/></index>
		<index><attribute label="public"/></index>
		<index><attribute label="abbrev"/></index>
		<index><attribute label="formula"/></index>
		<index><attribute label="mass"/></index>
		<index><attribute label="owner"/></index>
		<index><attribute label="abstractCompound"/></index>
		

		
		
		
	}
		
		
		my $searchName = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($roles->[$i]->name());
		
		$mapping->addAlias({
			objectType => "Role",
			aliasType => "ModelSEED",
			alias => $roles->[$i]->id(),
			uuid => $role->uuid()
		});
	}


}

sub createMapping {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["biochemistry"],{
		name => $self->username()."/primary"
	});
	my $mapping = $self->om()->create("Mapping",{name=>$args->{name}});
	$mapping->biochemistry_uuid($args->{biochemistry});
	my $roles = $self->figmodel()->database()->get_objects("role");
	for (my $i=0; $i < @{$roles}; $i++) {
		my $searchName = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($roles->[$i]->name());
		my $role = $mapping->create("Role",{
			locked => "0",
			name => $roles->[$i]->name(),
			searchname => $searchName,
			seedfeature => $roles->[$i]->exemplarmd5()
		});
		$mapping->addAlias({
			objectType => "Role",
			aliasType => "ModelSEED",
			alias => $roles->[$i]->id(),
			uuid => $role->uuid()
		});
	}
	my $subsystems = $self->figmodel()->database()->get_objects("subsystem");
	for (my $i=0; $i < @{$subsystems}; $i++) {
		my $searchName = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($subsystems->[$i]->name());
		my $ss = $mapping->create("Roleset",{
			locked => "0",
			name => $subsystems->[$i]->name(),
			searchname => $searchName,
		});
		$mapping->addAlias({
			objectType => "Roleset",
			aliasType => "ModelSEED",
			alias => $subsystems->[$i]->id(),
			uuid => $ss->uuid()
		});
	}
	my $ssroles = $self->figmodel()->database()->get_objects("ssroles");
	for (my $i=0; $i < @{$ssroles}; $i++) {
		my $ss = $mapping->getObjectByAlias("Roleset",$ssroles->[$i]->SUBSYSTEM());
		if (defined($ss)) {
			my $role = $mapping->getObjectByAlias("Role",$ssroles->[$i]->ROLE());
			if (defined($role)) {
				push(@{$ss->role()},$role);
			}
		}
	}
	my $complexes = $self->figmodel()->database()->get_objects("complex");
	for (my $i=0; $i < @{$complexes}; $i++) {
		my $complex = $mapping->create("Complex",{
			locked => "0",
			name => "",
			searchname => "",
		});
		$mapping->addAlias({
			objectType => "Complex",
			aliasType => "ModelSEED",
			alias => $complexes->[$i]->id(),
			uuid => $complex->uuid()
		});
	}
	my $complexRoles = $self->figmodel()->database()->get_objects("cpxrole");
	for (my $i=0; $i < @{$complexRoles}; $i++) {
		my $complex = $mapping->getObjectByAlias("Complex",$complexRoles->[$i]->COMPLEX());
		if (defined($complex)) {
			my $role = $mapping->getObjectByAlias("Role",$complexRoles->[$i]->ROLE());
			my $type = "triggering";
			if ($complexRoles->type() eq "L") {
				$type = "involved";	
			}
			$complex->create("ComplexRole",{
				role_uuid => $role->uuid(),
				optional => "0",
				type => $type
			});
		}
	}
	my $reactionRules = $self->figmodel()->database()->get_objects("rxncpx");
	for (my $i=0; $i < @{$reactionRules}; $i++) {
		if ($reactionRules->[$i]->master() eq "1") {
			my $complex = $mapping->getObjectByAlias("Complex",$reactionRules->[$i]->COMPLEX());
			if (defined($complex)) {
				my $rxnInstance = $mapping->biochemistry()->getObjectByAlias("ReactionInstance",$reactionRules->[$i]->REACTION());
				if (defined($rxnInstance)) {
					my $rule = $mapping->create("ReactionRule",{
						locked => "0",
						reaction_uuid => $rxnInstance->parent()->uuid(),
						compartment_uuid => $rxnInstance->compartment_uuid(),
						direction => $rxnInstance->parent()->reversibility(),
						transprotonNature => "balanced"
					});					
					push(@{$complex->reactionrules()},$rule);
					for (my $j=0; $j < @{$rxnInstance->transports()}; $j++) {
						$rule->create("ReactionRuleTransport",{
							compartmentIndex => $rxnInstance->transports()->[$j]->compartmentIndex(),
							compartment_uuid => $rxnInstance->transports()->[$j]->compartment_uuid(),
							compound_uuid => $rxnInstance->transports()->[$j]->compound_uuid(),
							coefficient => $rxnInstance->transports()->[$j]->coefficient()
						});
					}
				}
			}
		}
	}
	return $mapping;	
}

__PACKAGE__->meta->make_immutable;
