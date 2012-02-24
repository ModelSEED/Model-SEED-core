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
use ModelSEED::MS::ReactionSet;
use ModelSEED::MS::CompoundSet;
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
has 'reactionSet' => (is => 'ro', isa => 'ArrayRef[ModelSEED::MS::ReactionSet]', lazy => 1, builder => '_load_reactionSet');
has 'compoundSet' => (is => 'ro', isa => 'ArrayRef[ModelSEED::MS::CompoundSet]', lazy => 1, builder => '_load_compoundSet');
#Object data
has 'loadedSubObjects' => (is => 'ro',isa => 'HashRef[Str]',required => 1);
has 'indecies' => (is => 'ro',isa => 'HashRef',default => sub{{}});
#Constants
has 'dbAttributes' => (is => 'ro', isa => 'ArrayRef[Str]',default => ["uuid","modDate","locked","id","name","abbreviation","cksum","unchargedFormula","formula","mass","defaultCharge","deltaG","deltaGErr"]);
has 'dbType' => (is => 'ro', isa => 'Str',default => "Compound");
#Internally maintained variables
has 'changed' => (is => 'rw', isa => 'Bool',default => 0);

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
		my $subobjects = {
			compounds => "ModelSEED::MS::Compound",
			reactions => "ModelSEED::MS::Reaction",
			media => "ModelSEED::MS::Media",
			reactionSet => "ModelSEED::MS::ReactionSet",
			compoundSet => "ModelSEED::MS::CompoundSet",
		};
		my $array = ["compounds","reactions","media","reactionSet","compoundSet"];
		for (my $i=0; $i < @{$array}; $i++) {
			my $type = $array->[$i];
			if (defined($params->{rawdata}->{relations}->{$type})) {
				$params->{$type} = [];
				foreach my $data (@{$params->{rawdata}->{relations}->{$type}}) {
					my $class = $subobjects->{$type};
					my $obj = $class->new({biochemistry => $self,rawdata => $data});
					push(@{$params->{$type}},$obj);
				}
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
    if (!defined($om)) {
    	ModelSEED::utilities::ERROR("No ObjectManager");
    }
    
    
    
    
    
    
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

sub serializeToDB {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{});
	my $data = {};
	my $attributes = $self->dbAttributes();
	for (my $i=0; $i < @{$attributes}; $i++) {
		my $function = $attributes->[$i];
		$data->{attributes}->{$function} = $self->$function();
	}
	my $rodbClasses = {
		media => "BiochemistryMedia",
		compartments => "BiochemistryCompartment",
		compounds => "BiochemistryCompound",
		compoundsets => "BiochemistryCompoundset",
		reactions => "BiochemistryReaction",
		reactionsets => "BiochemistryReactionset"
	};
	my $subObjectRelations = {
		"media" => ["media","media_uuid"],
		"compartments" => ["compartments","compartment_uuid"],
		"compounds" => ["compounds","compound_uuid"],
		"reactions" => ["reactions","reaction_uuid"],
		"compoundsets" => ["compoundSets","compoundset_uuid"],
		"reactionsets" => ["reactionSets","reactionset_uuid"]
	};
	my $relations = ["media","compartments","compounds","reactions","compoundsets","reactionsets"];
	for (my $i=0; $i < @{$relations}; $i++) {
		my $relation = $relations->[$i];
		my $rodbClass = $rodbClasses->{$relation};
		if (defined($subObjectRelations->{$relation})) {
			my $function = $subObjectRelations->{$relation}->[0];
			$data->{relations}->{$relation} = [];
			foreach my $obj ($self->$function()) {
				push(@{$data->{relations}->{$relation}},{
					type => $rodbClass,
					attributes => {
						biochemistry_uuid => $self->uuid(),
        				$subObjectRelations->{$relation}->[1] => $obj->uuid(),
					}
				});
			}
		} else {
			#Do nothing for now
		}
	}
	return $data;
}

######################################################################
#Query Functions
######################################################################
sub getCompound {
    my ($self,$query) = @_;
    return $self->getObject({type => "Compound",query => $query});
}

sub getReaction {
    my ($self,$query) = @_;
    return $self->getObject({type => "Reaction",query => $query});
}

sub getReactionSet {
    my ($self,$query) = @_;
    return $self->getObject({type => "ReactionSet",query => $query});
}

sub getCompoundSet {
    my ($self,$query) = @_;
    return $self->getObject({type => "CompoundSet",query => $query});
}

sub getObject {
	my ($self,$args) = @_;
	my $objects = $self->getObjects($args);
	return $objects->[0];
}

sub getObjects {
    my ($self,$args) = @_;
    $args = ModelSEED::utilities::ARGS($args,["type","query"],{});
    $self->checkType($args->{type});
    my $hits = [];
    my $first = 1;
    foreach my $attribute (keys(%{$args->{query}})) {
    	if (!defined($self->indecies()->{$args->{type}}->{$attribute})) {
    		$self->buildIndex({type => $args->{type},attribute => $attribute});
    	}
    	if (!defined($self->indecies()->{$args->{type}}->{$attribute}->{$args->{query}->{$attribute}})) {
    		return [];	
    	}
    	my $newHits = $self->indecies()->{$args->{type}}->{$attribute}->{$args->{query}->{$attribute}};
    	if (@{$hits} > 0) {
    		my $hitsHash = {};
    		for (my $i=0; $i < @{$newHits}; $i++) {
	    		$hitsHash->{$newHits->[$i]} = 0;
	    	}
	    	for (my $i=0; $i < @{$hits}; $i++) {
	    		if (defined($hitsHash->{$hits->[$i]})) {
	    			$hitsHash->{$hits->[$i]} = 1;
	    		}
	    	}
	    	$hits = [];
	    	foreach my $hit (keys(%{$hitsHash})) {
	    		if ($hitsHash->{$hit} == 1) {
	    			push(@{$hits},$hit);
	    		}
	    	}
    	} else {
    		push(@{$hits},@{$newHits});
    	}
    	if (@{$hits} == 0) {
    		return [];
    	}
    	$first = 0;
    }
    return $hits;
}

sub checkType {
	my ($self,$type) = @_;
	my $types = {
    	Compound => "compounds",
    	Reaction => "reactions",
    	Media => "media",
    	CompoundSet => "compoundSets",
    	ReactionSet => "reactionSets"
    };
    if (!defined($types->{$type})) {
    	ModelSEED::utilities::ERROR("Type ".$type." not recognized!");
    }
    return $types->{$type};
}

sub clearIndex {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		type => undef,
		attribute => undef
	});
	if (!defined($args->{type})) {
		$self->indecies({});
	} else {
		$self->checkType($args->{type});
		if (!defined($args->{attribute})) {
			$self->indecies()->{$args->{type}} = {};	
		} else {
			$self->indecies()->{$args->{type}}->{$args->{attribute}} = {};
		}
	}
}

sub buildIndex {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["type","attribute"],{});
	my $function = $self->checkType($args->{type});
	my $objects = $self->$function();
	my $attribute = $args->{attribute};
	for (my $i=0; $i < @{$objects}; $i++) {
		push(@{$self->indecies()->{$args->{type}}->{$attribute}->{$objects->[$i]->$attribute()}},$objects->[$i]);
	}
}

__PACKAGE__->meta->make_immutable;
1;
