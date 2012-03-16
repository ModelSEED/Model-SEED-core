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
use ModelSEED::MS::utilityFunctions;
use ModelSEED::MS::Annotation;

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
		$args->{source} = $self->determineGenomeSource($args->{genomeid});	
	}
	if (!defined($args->{mapping})) {
		$args->{mapping} = $self->getMappingObject($args->{mapping_uuid});
	}
	$annoationObj->mapping_uuid($args->{mapping}->uuid());
	my $genomeData = $self->getGenomeData($args);
	my $genomeObj = ModelSEED::MS::Genome->new($genomeData);
	my $annoationObj = ModelSEED::MS::Annotation->new();
	$annoationObj->add($genomeObj);
	if (!defined($genomeData->{features})) {
		$genomeData->{features} = $self->getGenomeFeatures($args);
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
					my $roleObj = $self->getRoleObj({mapping => $args->{mapping},roleString => $row->{ROLES}->[$j]);
					my $ftrRoleObj = ModelSEED::MS::FeatureRole->new({
						feature_uuid => $featureObj->uuid(),
						role_uuid => $roleObj->uuid(),
						compartment => $row->{COMPARTMENT}->[0],
						comment => $row->{COMMENT}->[0],
						delimiter => $row->{DELIMITER}->[0]
					});
						
					
					
					
# FUNCTIONS:
sub getRoleObj {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities->ARGS($args,["roleString","mapping"],{});					
	my $searchName = ModelSEED::MS::utilityFunctions::convertRoleToSearchRole($args->{roleString});
	my $roleObj = $args->{mapping}->getObject("Role",{searchname => $searchName});
	if (!defined($roleObj)) {
		$roleObj = ModelSEED::MS::Role->new({
			name => $args->{roleString},
			searchname => $searchName,
			seedfeature => 
		});
	}				


		{name => 'name',perm => 'rw',type => 'Str',req => 0,default => ""},
		{name => 'searchname',perm => 'rw',type => 'varchar',req => 0,default => ""},
		{name => 'seedfeature',perm => 'rw',type => 'Str',len => 36,req => 0}				
					
					
					
					
					
					
					
					
					 else {
						my $featureObj = 
					}
				}
			}
			push(@{$annoationObj->genomes()},$featureObj);
		}
	}
	
	{name => 'feature_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'role_uuid',perm => 'rw',type => 'uuid',req => 1},
		{name => 'compartment',perm => 'rw',type => 'Str',default => "unknown"},
		{name => 'comment',perm => 'rw',type => 'Str',default => ""},
		{name => 'complete_string',perm => 'rw',type => 'Str',default => ""},
	
}

sub buildSerialAnnotation {
	my ($self,$args) = @_;
	my $mooseObj = $self->buildMooseAnnotation();
	return $mooseObj->serializeToDB();
}

sub determineGenomeSource {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities->ARGS($args,["genomeid"],{});
	my $result = $self->sapsvr()->exists({-type => 'Genome',-ids => [$self->genome()]});
	if ($result->{$self->genome()} eq "1") {
		return "PUBSEED";
	}
	my $result = $self->MSSeedSupportClient()->genomeTypes({ids => [$self->genome()]});
	return $result->{$self->genome()};
}


__PACKAGE__->meta->make_immutable;