########################################################################
# ModelSEED::MS::Factories - This is the factory for producing the moose objects from the SEED data
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::utilities;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Utilities::GlobalFunctions;

package ModelSEED::MS::Factories::SEEDFactory
use SAPserver;
use MSSeedSupportClient;

# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ObjectManager',weak_ref => 1);


# ATTRIBUTES:
has sapsvr => ( is => 'rw', isa => 'SAPserver', lazy => 1, builder => '_buildsapsvr' );
has msseedsvr => ( is => 'rw', isa => 'MSSeedSupportClient', lazy => 1, builder => '_buildmsseedsvr' );


# BUILDERS:
sub _buildsapsvr { return SAPserver->new(); }
sub _buildmsseedsvr { return MSSeedSupportClient->new(); }


# CONSTANTS:
sub _type { return 'SEEDFactory'; }


# FUNCTIONS:
sub buildMooseAnnotation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities->ARGS($args,["genome_id"],{
		mapping_uuid => undef,
		mapping => undef,
		source => undef
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->getGenomeSource($args->{genomeid});	
	}
	if (!defined($args->{mapping})) {
		$args->{mapping} = $self->getMappingObject({mapping_uuid => $args->{mapping_uuid}});
	}
	$annoationObj->mapping_uuid($args->{mapping}->uuid());
	my $genomeData = $self->getGenomeAttributes({genome_id => $args->{genome_id},source => $args->{source}});
	my $genomeObj = ModelSEED::MS::Genome->new({
		id => $args->{genome_id},
		name => $genomeData->{name},
		source => $args->{source},
		taxonomy => $genomeData->{taxonomy},
		size => $genomeData->{size},
		gc => $genomeData->{gc}
	});
	my $annoationObj = ModelSEED::MS::Annotation->new();
	$annoationObj->add($genomeObj);
	if (!defined($genomeData->{features})) {
		$genomeData->{features} = $self->getGenomeFeatures({genome_id => $args->{genome_id},source => $args->{source}});
	}
	for (my $i=0; $i < @{$genomeData->{features}}; $i++) {
		my $row = $genomeData->{features}->[$i]; 
		if (defined($row->{ID}->[0]) && defined($row->{START}->[0]) && defined($row->{STOP}->[0]) && defined($row->{CONTIG}->[0])) {
			my $featureObj = ModelSEED::MS::Feature->new({
				id => $row->{ID}->[0],
				genome_uuid => $genomeObj->uuid(),
				start => $row->{START}->[0],
				stop => $row->{STOP}->[0],
				contig => $row->{CONTIG}->[0]
			});
			if (defined($row->{ROLES}->[0])) {
				for (my $j=0; $j < @{$row->{ROLES}}; $j++) {
					my $roleObj = $self->getRoleObject({mapping => $args->{mapping},roleString => $row->{ROLES}->[$j]});
					my $ftrRoleObj = ModelSEED::MS::FeatureRole->new({
						feature_uuid => $featureObj->uuid(),
						role_uuid => $roleObj->uuid(),
						compartment => $row->{COMPARTMENT}->[0],
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
	$args = ModelSEED::utilities->ARGS($args,["roleString","mapping"],{});					
	my $searchName = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($args->{roleString});
	my $roleObj = $args->{mapping}->getObject("Role",{searchname => $searchName});
	if (!defined($roleObj)) {
		$roleObj = ModelSEED::MS::Role->new({
			name => $args->{roleString},
			searchname => $searchName
		});
	}
	$args->{mapping}->add($roleObj);			
	return $roleObj;
}

sub getMappingObject {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		mapping_uuid => undef
	});
	my $mappingObj;
	if (defined($args->{mapping_uuid})) {
		$mappingObj = $self->parent()->getObject("Mapping",{uuid => $args->{mapping_uuid}});
		if (!defined($mappingObj)) {
			ModelSEED::utilities::ERROR("Mapping with uuid ".$args->{mapping_uuid}." not found in database!");
		}
	} else {
		$mappingObj = ModelSEED::MS::Mapping->new({
			parent => $self->parent()
		});
	}
	return $mappingObj;
}

sub getGenomeSource {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genomeid"],{});
	my $result = $self->sapsvr()->exists({-type => 'Genome',-ids => [$self->genome()]});
	if ($result->{$self->genome()} eq "1") {
		return "PUBSEED";
	}
	my $result = $self->MSSeedSupportClient()->genomeType({ids => [$self->genome()]});
	return $result->{$self->genome()};
}

sub getGenomeFeatures {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genomeid"],{
		source => undef,
		withSequences => 0 
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->getGenomeSource({genomeid => $args->{genomeid}});
	}
	my $features;
	if ($args->{source} eq "PUBSEED") {
		my $featureHash = $self->sapsvr()->all_features({-ids => $args->{genomeid}});
		if (!defined($featureHash->{$args->{genomeid}})) {
			ModelSEED::utilities::ERROR("Could not load features for pubseed genome:".$args->{genomeid});
		}
		my $featureList = $featureHash->{$args->{genomeid}};
		my $functions = $self->sapsvr()->ids_to_functions({-ids => $featureList});
		my $locations = $self->sapsvr()->fid_locations({-ids => $featureList});
		#my $aliases = $self->sapsvr()->fids_to_ids({-ids => $featureList,-protein => 1});
		my $sequences;
		if ($args->{withSequences} == 1) {
			$sequences = $self->sapsvr()->ids_to_sequences({-ids => $featureList,-protein => 1});
		}
		for (my $i=0; $i < @{$featureList}; $i++) {
			my $row = {ID => [$featureList->[$i]],TYPE => "peg"};
			if ($featureList->[$i] =~ m/\d+\.\d+\.([^\.]+)\.\d+$/) {
				$row->{TYPE}->[0] = $1;
			}
			print $locations->{$featureList->[$i]}->[0]."\n";
			if (defined($locations->{$featureList->[$i]}->[0]) && $locations->{$featureList->[$i]}->[0] =~ m/(\d+)([\+\-])(\d+)$/) {
				$row->{CONTIG}->[0] = "?";
				if ($2 eq "-") {
					$row->{START}->[0] = ($1-$3);
					$row->{STOP}->[0] = ($1);
					$row->{DIRECTION}->[0] = "rev";
				} else {
					$row->{START}->[0] = ($1);
					$row->{STOP}->[0] = ($1+$3);
					$row->{DIRECTION}->[0] = "for";
				}
			}
			if (defined($aliases->{$featureList->[$i]})) {
				my $types = [keys(%{$aliases->{$featureList->[$i]}})];
				for (my $j=0; $j < @{$types}; $j++) {
					for (my $k=0; $k < @{$aliases->{$featureList->[$i]}->{$types->[$j]}}; $k++) {
						push(@{$row->{ALIASES}},$aliases->{$featureList->[$i]}->{$types->[$j]}->[$k]);
						push(@{$row->{ALIASETYPES}},$types->[$j]);
					}
				}
			}
			if (defined($functions->{$featureList->[$i]})) {
				my $output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles($functions->{$featureList->[$i]});
				$row->{COMPARTMENT}->[0] = $output->{compartment};
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
		my $output = $self->msseedsvr()->genomeData({ids => [$args->{genomeid}],username => $self->parent()->user()->login(),password => $self->parent()->user()->password()});
		if (!defined($output->{features})) {
			ModelSEED::utilities::ERROR("Could not load data for rast genome:".$args->{genomeid});
		}
		for (my $i=0; $i < $output->{features}; $i++) {
			my $ftr = $output->{features}->[$i];
			my $row = {ID => [$ftr->{ID}->[0]],TYPE => "peg"};
			if ($ftr->{ID}->[0] =~ m/\d+\.\d+\.([^\.]+)\.\d+$/) {
				$row->{TYPE}->[0] = $1;
			}
			print $ftr->{LOCATION}->[0]."\n";
			if (defined($ftr->{LOCATION}->[0]) && $ftr->{LOCATION}->[0] =~ m/(\d+)([\+\-])(\d+)$/) {
				$row->{CONTIG}->[0] = "?";
				if ($2 eq "-") {
					$row->{START}->[0] = ($1-$3);
					$row->{STOP}->[0] = ($1);
					$row->{DIRECTION}->[0] = "rev";
				} else {
					$row->{START}->[0] = ($1);
					$row->{STOP}->[0] = ($1+$3);
					$row->{DIRECTION}->[0] = "for";
				}
			}
			if (defined($ftr->{FUNCTION}->[0])) {
				my $output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles($ftr->{FUNCTION}->[0]);
				$row->{COMPARTMENT}->[0] = $output->{compartment};
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
	$args = ModelSEED::utilities::ARGS($args,["genomeid"],{
		source => undef
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->getGenomeSource({genomeid => $args->{genomeid}});
	}
	my $attributes;
	if ($args->{source} eq "PUBSEED") {
		my $genomeHash = $self->sapsvr()->genome_data({
			-ids => [$args->{genomeid}],
			-data => ["gc-content", "dna-size","name","taxonomy"]
		});
		if (!defined($genomeHash->{$args->{genomeid}})) {
			ModelSEED::utilities::ERROR("Could not load data for pubseed genome:".$args->{genomeid});
		}
		$attributes->{name} = $genomeHash->{$args->{genomeid}}->[2];
		$attributes->{taxonomy} = $genomeHash->{$args->{genomeid}}->[3];
		$attributes->{size} = $genomeHash->{$args->{genomeid}}->[1];
		$attributes->{gc} = $genomeHash->{$args->{genomeid}}->[0];
	} else {
		if (!defined($self->parent()) || !defined($self->parent()->user())) {
			ModelSEED::utilities::USEERROR("Cannot retrieve a private genome or metagneome without specifying username or password!");
		}
		my $output = $self->msseedsvr()->genomeData({ids => [$args->{genomeid}],username => $self->parent()->user()->login(),password => $self->parent()->user()->password()});
		if (!defined($output->{features})) {
			ModelSEED::utilities::ERROR("Could not load data for rast genome:".$args->{genomeid});
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