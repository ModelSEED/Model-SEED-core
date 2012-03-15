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
use ModelSEED::utilities
use ModelSEED::MS::Annotation

package ModelSEED::MS::Factories::SEEDFactory
use SAPserver;
use MSSeedSupportClient;

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
	$args = ModelSEED::utilities->ARGS($args,["genomeid"],{
		source => undef
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->determineGenomeSource($args->{genomeid});	
	}
	my $genomeData = $self->getGenomeData($args);
	my $genomeObj = ModelSEED::MS::Genome->new($genomeData);
	my $annoationObj = ModelSEED::MS::Annotation->new();
	push(@{$annoationObj->genomes()},$genomeObj);
	if (!defined($genomeData->{features})) {
		$genomeData->{features} = $self->getGenomeFeatures($args);
	}
	for (my $i=0; $i < @{$genomeData->{features}}; $i++) {
		my $featureObj = ModelSEED::MS::Feature->new({
			
		});
		push(@{$annoationObj->genomes()},$featureObj);
	}
	
	
	
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

has name => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has source => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', required => 1 );
has class => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has taxonomy => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has cksum => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has size => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has genes => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has gc => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has etcType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );

sub buildSerialAnnotation {
	my ($self,$args) = @_;
	
}



__PACKAGE__->meta->make_immutable;