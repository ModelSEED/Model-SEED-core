use JSON::Any;
use strict;
use Bio::KBase::Exceptions;

use URI;
use ModelSEED::Database::MongoDBSimple;
use Bio::KBase::IDServer::Client;
use ModelSEED::Auth::Basic;
use ModelSEED::Store;
use Data::UUID;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;

my $self;
$self->{_db} =
  ModelSEED::Database::MongoDBSimple->new(
			   { db_name => "modelObjectStore", host => "birch.mcs.anl.gov" } );
$self->{_auth} =
  ModelSEED::Auth::Basic->new( { username => "kbase", password => "kbase" } )
  ;
$self->{_store} =
  ModelSEED::Store->new( { auth => $self->{_auth}, database => $self->{_db} } );

my $biochem = $self->{_store}->get_object("biochemistry/kbase/default");
my $mapping = $self->{_store}->get_object("mapping/kbase/default");
$mapping->biochemistry($biochem);

#Issuing the mapping a new uuid because it will be altered during this function
$mapping->uuid( Data::UUID->new()->create_str() );

#Creating the annotation from the input genome object
my $size = 0;
my $gc   = 0;
for ( my $i = 0 ; $i < @{ $in_genome->{contigs} } ; $i++ ) {
	my $dna = $in_genome->{contigs}->[$i]->{dna};
	my $size += length($dna);
	for ( my $j = 0 ; $j < length($dna) ; $j++ ) {
		if ( substr( $dna, $j, 1 ) =~ m/[gc]/ ) {
			$gc++;
		}
	}
}
$gc = $gc / $size;
my $annotation = ModelSEED::MS::Annotation->new(
								{
								  name         => $in_genome->{scientific_name},
								  mapping_uuid => $mapping->uuid(),
								  mapping      => $mapping,
								  genomes      => [
									   {
										 name => $in_genome->{scientific_name},
										 source   => $in_genome->{source},
										 id       => $in_genome->{genome_id},
										 cksum    => "unknown",
										 class    => "unknown",
										 taxonomy => $in_genome->{domain},
										 etcType  => "unknown",
										 size     => $size,
										 gc       => $gc
									   }
								  ]
								}
);
for ( my $i = 0 ; $i < @{ $in_genome->{features} } ; $i++ ) {
	my $ftr = $in_genome->{features}->[$i];
	my $ftr = $annotation->create(
			   "Feature",
			   {
				 id          => $ftr->{id},
				 type        => $ftr->{type},
				 sequence    => $ftr->{protein_translation},
				 genome_uuid => $annotation->genomes()->[0]->uuid(),
				 start       => $ftr->{location}->[0]->[1],
				 stop        =>
				   ( $ftr->{location}->[0]->[1] + $ftr->{location}->[0]->[3] ),
				 contig    => $ftr->{location}->[0]->[0],
				 direction => $ftr->{location}->[0]->[2],
			   }
	);
	my $output =
	  ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles(
															 $ftr->{function} );
	if ( defined( $output->{roles} ) ) {
		for ( my $j = 0 ; $j < @{ $output->{roles} } ; $j++ ) {
			my $role =
			  $mapping->get_object( "Role",
									{ name => $output->{roles}->[$j] } );
			if ( !defined($role) ) {
				$role =
				  $mapping->create( "Role",
									{ name => $output->{roles}->[$j] } );
			}
			$ftr->create(
						  "FeatureRole",
						  {
							 role_uuid   => $role->uuid(),
							 compartment => $output->{compartments},
							 delimiter   => $output->{delimiter},
							 comment     => $output->{comment}
						  }
			);
		}
	}
}

#Running the reconstruction algorithm
my $mdl = $annotation->createStandardFBAModel( { prefix => "Kbase", } );

#Getting KBase ID
my $id_server = Bio::KBase::IDServer::Client->new();
my $kbid = $id_server->allocate_id_range( "fbamod", 1 ) + 0;
$mdl->id($kbid);
$mdl->defaultNameSpace("KBase");

#Saving the model to the mongodb document store
my $out_model = $mdl->serializeToDB();
$self->{_store}->save_data( "model/kbase/" . $mdl->id(), $out_model );
$store->set_public( "model/kbase/" . $mdl->id(), 1 );

#Saving the annotation to the mongodb document store
$self->{_store}->save_data( "annotation/kbase/" . $annotation->uuid(),
							$annotation->serializeToDB() );
$store->set_public( "annotation/kbase/" . $annotation->uuid(), 1 );

#Saving the mapping to the mongodb document store
$self->{_store}
  ->save_data( "mapping/kbase/" . $mapping->uuid(), $mapping->serializeToDB() );
$store->set_public( "mapping/kbase/" . $mapping->uuid(), 1 );
