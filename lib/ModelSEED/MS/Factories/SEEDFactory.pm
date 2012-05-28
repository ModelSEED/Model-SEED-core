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
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Utilities::GlobalFunctions;
package ModelSEED::MS::Factories::SEEDFactory;
use Moose;
use SAPserver;
use MSSeedSupportClient;

# ATTRIBUTES:
has sapsvr => ( is => 'rw', isa => 'SAPserver', lazy => 1, builder => '_buildsapsvr' );
has msseedsvr => ( is => 'rw', isa => 'MSSeedSupportClient', lazy => 1, builder => '_buildmsseedsvr' );
has om => ( is => 'rw', isa => 'ModelSEED::Store');


# BUILDERS:
sub _buildsapsvr { return SAPserver->new(); }
sub _buildmsseedsvr { return MSSeedSupportClient->new(); }


# CONSTANTS:
sub _type { return 'SEEDFactory'; }


# FUNCTIONS:
sub buildMooseAnnotation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genome_id"],{
		mapping_uuid => undef,
		mapping => undef,
		source => undef
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->getGenomeSource({genome_id => $args->{genome_id}});	
	}
	if (!defined($args->{mapping})) {
		$args->{mapping} = $self->getMappingObject({mapping_uuid => $args->{mapping_uuid}});
	}
	my $genomeData = $self->getGenomeAttributes({genome_id => $args->{genome_id},source => $args->{source}});
	my $annoationObj;
	if (defined($self->om())) {
		$annoationObj = $self->om()->create("Annotation");
	} else {
		$annoationObj = ModelSEED::MS::Annotation->new({
			name => $genomeData->{name}
		});
	}
	my $genomeObj = $annoationObj->create("Genome",{
		id => $args->{genome_id},
		name => $genomeData->{name},
		source => $args->{source},
		taxonomy => $genomeData->{taxonomy},
		size => $genomeData->{size},
		gc => $genomeData->{gc},
	});
	$annoationObj->mapping_uuid($args->{mapping}->uuid());
	$annoationObj->mapping($args->{mapping});
	if (!defined($genomeData->{features})) {
		$genomeData->{features} = $self->getGenomeFeatures({genome_id => $args->{genome_id},source => $args->{source}});
	}
	for (my $i=0; $i < @{$genomeData->{features}}; $i++) {
		my $row = $genomeData->{features}->[$i]; 
		if (defined($row->{ID}->[0]) && defined($row->{START}->[0]) && defined($row->{STOP}->[0]) && defined($row->{CONTIG}->[0])) {
			my $featureObj = $annoationObj->create("Feature",{
				id => $row->{ID}->[0],
				genome_uuid => $genomeObj->uuid(),
				start => $row->{START}->[0],
				stop => $row->{STOP}->[0],
				contig => $row->{CONTIG}->[0]
			});
			if (defined($row->{ROLES}->[0])) {
				for (my $j=0; $j < @{$row->{ROLES}}; $j++) {
					my $roleObj = $self->getRoleObject({mapping => $args->{mapping},roleString => $row->{ROLES}->[$j]});
					my $ftrRoleObj =$featureObj->create("FeatureRole",{
						feature_uuid => $featureObj->uuid(),
						role_uuid => $roleObj->uuid(),
						compartment => join("|",@{$row->{COMPARTMENT}}),
						comment => $row->{COMMENT}->[0],
						delimiter => $row->{DELIMITER}->[0]
					});
				}
			}
		}
	}
	return $annoationObj;
}

sub buildSerialAnnotation {
	my ($self,$args) = @_;
	my $mooseObj = $self->buildMooseAnnotation();
	return $mooseObj->serializeToDB();
}
				
# FUNCTIONS:
sub getRoleObject {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["roleString","mapping"],{});					
	my $searchName = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($args->{roleString});
	my $roleObj = $args->{mapping}->getObject("Role",{searchname => $searchName});
	if (!defined($roleObj)) {
		$roleObj = $args->{mapping}->create("Role",{
			name => $args->{roleString},
		});
	}
	return $roleObj;
}

sub getMappingObject {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		mapping_uuid => undef
	});
	my $mappingObj;
	if (defined($args->{mapping_uuid})) {
		$mappingObj = $self->om()->get("Mapping",$args->{mapping_uuid});
		if (!defined($mappingObj)) {
			ModelSEED::utilities::ERROR("Mapping with uuid ".$args->{mapping_uuid}." not found in database!");
		}
	} else {
		$mappingObj = $self->om()->create("Mapping",{name=>"Test"});
	}
	return $mappingObj;
}

sub getGenomeSource {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genome_id"],{});
	my $result = $self->sapsvr()->exists({-type => 'Genome',-ids => [$args->{genome_id}]});
	if ($result->{$args->{genome_id}} eq "1") {
		return "PUBSEED";
	}
	$result = $self->MSSeedSupportClient()->genomeType({ids => [$args->{genome_id}]});
	return $result->{$args->{genome_id}};
}

sub getGenomeFeatures {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genome_id"],{
		source => undef,
		withSequences => 0 
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->getGenomeSource({genome_id => $args->{genome_id}});
	}
	my $features;
	if ($args->{source} eq "PUBSEED") {
		my $featureHash = $self->sapsvr()->all_features({-ids => $args->{genome_id}});
		if (!defined($featureHash->{$args->{genome_id}})) {
			ModelSEED::utilities::ERROR("Could not load features for pubseed genome:".$args->{genome_id});
		}
		my $featureList = $featureHash->{$args->{genome_id}};
		my $functions = $self->sapsvr()->ids_to_functions({-ids => $featureList});
		my $locations = $self->sapsvr()->fid_locations({-ids => $featureList});
		#my $aliases = $self->sapsvr()->fids_to_ids({-ids => $featureList,-protein => 1});
		my $sequences;
		if ($args->{withSequences} == 1) {
			$sequences = $self->sapsvr()->ids_to_sequences({-ids => $featureList,-protein => 1});
		}
		for (my $i=0; $i < @{$featureList}; $i++) {
			my $row = {ID => [$featureList->[$i]],TYPE => ["peg"]};
			if ($featureList->[$i] =~ m/\d+\.\d+\.([^\.]+)\.\d+$/) {
				$row->{TYPE}->[0] = $1;
			}
			if (defined($locations->{$featureList->[$i]}->[0]) && $locations->{$featureList->[$i]}->[0] =~ m/^(.+)_(\d+)([\+\-])(\d+)$/) {
				my $array = [split(/:/,$1)];
				$row->{CONTIG}->[0] = $array->[1];
				if ($3 eq "-") {
					$row->{START}->[0] = ($2-$4);
					$row->{STOP}->[0] = ($2);
					$row->{DIRECTION}->[0] = "rev";
				} else {
					$row->{START}->[0] = ($2);
					$row->{STOP}->[0] = ($2+$4);
					$row->{DIRECTION}->[0] = "for";
				}
			}
			if (defined($functions->{$featureList->[$i]})) {
				my $output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles($functions->{$featureList->[$i]});
				$row->{COMPARTMENT} = $output->{compartments};
				$row->{COMMENT}->[0] = $output->{comment};
				$row->{DELIMITER}->[0] = $output->{delimiter};
				$row->{ROLES} = $output->{roles};
			}
			if (defined($sequences->{$featureList->[$i]})) {
				$row->{SEQUENCE}->[0] = $sequences->{$featureList->[$i]};
			}
			push(@{$features},$row);			
		}
	} else {
		if (!defined($self->parent()) || !defined($self->parent()->user())) {
			ModelSEED::utilities::USEERROR("Cannot retrieve a private genome or metagneome without specifying username or password!");
		}
		my $output = $self->msseedsvr()->genomeData({ids => [$args->{genome_id}],username => $self->parent()->user()->login(),password => $self->parent()->user()->password()});
		if (!defined($output->{features})) {
			ModelSEED::utilities::ERROR("Could not load data for rast genome:".$args->{genome_id});
		}
		for (my $i=0; $i < $output->{features}; $i++) {
			my $ftr = $output->{features}->[$i];
			my $row = {ID => [$ftr->{ID}->[0]],TYPE => "peg"};
			if ($ftr->{ID}->[0] =~ m/\d+\.\d+\.([^\.]+)\.\d+$/) {
				$row->{TYPE}->[0] = $1;
			}
			if (defined($ftr->{LOCATION}->[0]) && $ftr->{LOCATION}->[0] =~ m/^(.+)_(\d+)([\+\-])(\d+)$/) {
				my $array = [split(/:/,$1)];
				$row->{CONTIG}->[0] = $array->[1];
				if ($3 eq "-") {
					$row->{START}->[0] = ($2-$4);
					$row->{STOP}->[0] = ($2);
					$row->{DIRECTION}->[0] = "rev";
				} else {
					$row->{START}->[0] = ($2);
					$row->{STOP}->[0] = ($2+$4);
					$row->{DIRECTION}->[0] = "for";
				}
			}
			if (defined($ftr->{FUNCTION}->[0])) {
				my $output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles($ftr->{FUNCTION}->[0]);
				$row->{COMPARTMENT}->[0] = $output->{compartments};
				$row->{COMMENT}->[0] = $output->{comment};
				$row->{DELIMITER}->[0] = $output->{delimiter};
				$row->{ROLES} = $output->{roles};
			}
			if (defined($ftr->{SEQUENCE}->[0])) {
				$row->{SEQUENCE}->[0] = $ftr->{SEQUENCE}->[0];
			}
			push(@{$features},$row);
		}
	}
	return $features;
}

sub getGenomeAttributes {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genome_id"],{
		source => undef
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->getGenomeSource({genome_id => $args->{genome_id}});
	}
	my $attributes;
	if ($args->{source} eq "PUBSEED") {
		my $genomeHash = $self->sapsvr()->genome_data({
			-ids => [$args->{genome_id}],
			-data => ["gc-content", "dna-size","name","taxonomy"]
		});
		if (!defined($genomeHash->{$args->{genome_id}})) {
			ModelSEED::utilities::ERROR("Could not load data for pubseed genome:".$args->{genome_id});
		}
		$attributes->{name} = $genomeHash->{$args->{genome_id}}->[2];
		$attributes->{taxonomy} = $genomeHash->{$args->{genome_id}}->[3];
		$attributes->{size} = $genomeHash->{$args->{genome_id}}->[1];
		$attributes->{gc} = $genomeHash->{$args->{genome_id}}->[0];
	} else {
		if (!defined($self->parent()) || !defined($self->parent()->user())) {
			ModelSEED::utilities::USEERROR("Cannot retrieve a private genome or metagneome without specifying username or password!");
		}
		my $output = $self->msseedsvr()->genomeData({ids => [$args->{genome_id}],username => $self->parent()->user()->login(),password => $self->parent()->user()->password()});
		if (!defined($output->{features})) {
			ModelSEED::utilities::ERROR("Could not load data for rast genome:".$args->{genome_id});
		}
		$attributes->{name} = $output->{name};
		$attributes->{taxonomy} = $output->{taxonomy};
		$attributes->{size} = $output->{size};
		$attributes->{gc} = $output->{gc};
		$attributes->{features} = $output->{features};
	}
	return $attributes;
}


__PACKAGE__->meta->make_immutable;
