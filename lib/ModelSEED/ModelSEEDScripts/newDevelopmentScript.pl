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
use ModelSEED::FIGMODEL;

my $self;
$self->{_db} =
  ModelSEED::Database::MongoDBSimple->new(
			   { db_name => "modelObjectStore", host => "birch.mcs.anl.gov" } );
$self->{_auth} =
  ModelSEED::Auth::Basic->new( { username => "kbase", password => "kbase" } )
  ;
$self->{_store} =
  ModelSEED::Store->new( { auth => $self->{_auth}, database => $self->{_db} } );

my $figmodel = ModelSEED::FIGMODEL->new({username => "public",password => "public"});
my $ppoFactory = ModelSEED::MS::Factories::PPOFactory->new({
	figmodel => $figmodel,
	namespace => "public"
});
my $biochem = $ppoFactory->createBiochemistry();
my $mapping = $ppoFactory->createMapping({
	biochemistry => $biochem
});

#Saving the mapping to the mongodb document store
$self->{_store}->save_data( "biochemistry/kbase/default", $biochem->serializeToDB() );
$self->{_store}->save_data( "mapping/kbase/default", $mapping->serializeToDB() );
$self->{_store}->set_public( "biochemistry/kbase/default", 1 );
$self->{_store}->set_public( "mapping/kbase/default", 1 );
