########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::Media;
package ModelSEED::MS::Biochemistry;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

has 'om' => (is => 'ro', isa => 'ModelSEED::CoreApi');
has 'uuid' => (is => 'ro', isa => 'Str', required => 1);
has 'modDate' => (is => 'ro', isa => 'Str');
has 'locked' => (is => 'ro', isa => 'Int', required => 1,default => 1);
has 'public' => (is => 'ro', isa => 'Int', required => 1,default => 1);
has 'name' => (is => 'ro', isa => 'Str');
#Subobjects
has 'reactions' => (is => 'ro', isa => 'ArrayRef[ModelSEED::MS::Reaction]', lazy => 1, builder => '_load_reactions');
has 'compounds' => (is => 'ro', isa => 'ArrayRef[ModelSEED::MS::Compound]', lazy => 1, builder => '_load_compounds');
has 'media' => (is => 'ro', isa => 'ArrayRef[ModelSEED::MS::Media]', lazy => 1, builder => '_load_media');
#Object data
has 'loadedSubObjects' => (is => 'ro',isa => 'HashRef[Str]',required => 1);
#Constants
has 'dbAttributes' => (is => 'ro', isa => 'ArrayRef[Str]',default => ["uuid","modDate","locked","id","name","abbreviation","cksum","unchargedFormula","formula","mass","defaultCharge","deltaG","deltaGErr"]);
has 'dbType' => (is => 'ro', isa => 'Str',default => "Compound");

sub BUILDARGS {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{
		om => undef,# ModelSEED::CoreApi
		user => undef,# Username used in calls to the CoreApi
		rawdata => undef,#Raw data of form returned by raw data object manager API
		uuid => undef #UUID of the biochemistry object, used to retrieve the biochemistry data from the database
	});
	if (!defined($params->{rawdata}) && defined($params->{user}) && defined($params->{uuid}) && defined($params->{om})) {
		$params->{rawdata} = $params->{om}->getBiochemistry({
			uuid              => $params->{uuid},
			user              => $params->{user},
			with_all          => 1
		});
	}
	if (defined($params->{rawdata})) {
		if (defined($params->{rawdata}->{attributes})) {
			foreach my $attribute (keys(%{$params->{rawdata}->{attributes}})) {
				if (defined($params->{rawdata}->{attributes}->{$attribute}) && $params->{rawdata}->{attributes}->{$attribute} ne "undef") {
					$params->{$attribute} = $params->{rawdata}->{attributes}->{$attribute};
				}
			}
		}
		if (defined($params->{rawdata}->{relations}->{compounds})) {
			foreach my $cpd (@{$params->{rawdata}->{relations}->{compounds}}) {
				my $cpdobj = ModelSEED::MooseDB::Compound->new({biochemistry => $self,rawdata => $cpd});
				push(@{$params->{compounds}},$cpdobj);
			}
		}
		if (defined($params->{rawdata}->{relations}->{reactions})) {
			foreach my $rxn (@{$params->{rawdata}->{relations}->{reactions}}) {
				my $rxnobj = ModelSEED::MooseDB::Reaction->new({biochemistry => $self,rawdata => $rxn});
				push(@{$params->{reactions}},$rxnobj);
			}
		}
	}
	return $params;
}


sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{});
}

sub save {
    my ($self, $om) = @_;
    $om = $self->om unless(defined($om));
    die "No ObjectManager" unless defined($om);
    return $om->save($self->type, $self->serializeToDB());
}
    

sub _load_reactions {
    my ($self) = @_;
    my $rxns = $self->om()->getReactions({
    	biochemistry_uuid => $self->uuid(),
    });
    my $objs;
    for (my $i=0; $i < @{$rxns}; $i++) {
    	my $obj = ModelSEED::MS::Reaction->new({biochemistry => $self,rawdata => $rxns->[$i]});
    	push(@{$objs},$obj);
    }
    return $objs;
}

sub _load_compounds {
    my ($self) = @_;
    my $cpds = $self->om()->getCompounds({
    	biochemistry_uuid => $self->uuid(),
    });
    my $objs;
    for (my $i=0; $i < @{$cpds}; $i++) {
    	my $obj = ModelSEED::MS::Compound->new({biochemistry => $self,rawdata => $cpds->[$i]});
    	push(@{$objs},$obj);
    }
    return $objs;
}

sub _load_media {
    my ($self) = @_;
    my $medias = $self->om()->getMedia({
    	biochemistry_uuid => $self->uuid(),
    });
    my $objs;
    for (my $i=0; $i < @{$medias}; $i++) {
    	my $obj = ModelSEED::MS::Media->new({biochemistry => $self,rawdata => $medias->[$i]});
    	push(@{$objs},$obj);
    }
    return $objs;
}

__PACKAGE__->meta->make_immutable;
1;
