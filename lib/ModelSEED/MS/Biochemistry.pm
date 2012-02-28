########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
package ModelSEED::MS::Biochemistry;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::utilities;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::ReactionSet;
use ModelSEED::MS::CompoundSet;
use ModelSEED::MS::Media;
use Carp qw(cluck);
use namespace::autoclean;

has om => (is => 'ro', isa => 'ModelSEED::CoreApi');
has uuid => (is => 'ro', isa => 'Str', required => 1);
has modDate => (is => 'ro', isa => 'Str');
has locked => (is => 'ro', isa => 'Int', default => 0);
has public => (is => 'ro', isa => 'Int', default => 1);
has name => (is => 'ro', isa => 'Str');

# Subobjects
has reactions => (is => 'rw', default => sub { return []; },
    isa =>'ArrayRef[ModelSEED::MS::Reaction]');
has compounds => (is => 'rw', default => sub { return []; },
    isa => 'ArrayRef[ModelSEED::MS::Compound]');
has media => (is => 'rw', default => sub { return []; },
    isa => 'ArrayRef[ModelSEED::MS::Media]');
has reactionset => ( is => 'rw', default => sub { return []; },
    isa => 'ArrayRef[ModelSEED::MS::Reactionset]');
has compoundset => (is => 'rw', default => sub { return []; },
    isa => 'ArrayRef[ModelSEED::MS::Compoundset]');
has compartments => ( is => 'rw', default => sub { return []; },
    isa => 'ArrayRef[ModelSEED::MS::Compartment]');
# Constants
has dbAttributes => ( is => 'ro', isa => 'ArrayRef[Str]', builder => '_buildDbAttributes');
has indices => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => '_buildindices');

has dbType => (is => 'ro', isa => 'Str',default => "Compound");
#Internally maintained variables
has changed => (is => 'rw', isa => 'Bool',default => 0);

sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    return $params;
}

sub BUILD {
    my ($self, $params) = @_;
    my $rels = $params->{relationships};
    if(defined($rels)) {
		my $subObjects = {
			compounds => "ModelSEED::MS::Compound",
            compartments => "ModelSEED::MS::Compartment",
			reactions => "ModelSEED::MS::Reaction",
			media => "ModelSEED::MS::Media",
			reactionset => "ModelSEED::MS::Reactionset",
			compoundset => "ModelSEED::MS::Compoundset",
		};
        my $order = [qw(compounds compartments reactions media reactionset compoundset)];
        foreach my $name (@$order) {
            my $values = $rels->{$name};
            $params->{$name} = [];
            my $class = $subObjects->{$name};
            foreach my $data (@$values) {
                $data->{biochemistry} = $self;
                push(@{$self->{$name}}, $class->new($data));
            }
		}
        delete $params->{relationships}
    }
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

sub _load_compartments {
    my ($self) = @_;
    my $compartments = $self->om()->getCompartments({
        bioechemistry_uuid => $self->uuid()
    });
    map { $_ = ModelSEED::MS::Compartment->new($_) } @$compartments;
    return $compartments;
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
    my @relations = qw( media compartments compounds reactions compoundsets reactionsets );
	foreach my $relation (@relations) {
        $data->{relationships}->{$relation} = [];
        foreach my $obj ($self->$relation) {
            push(@{$data->{relationships}->{$relation}}, $obj->serializeToDB());
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

sub getReactionset {
    my ($self,$query) = @_;
    return $self->getObject({type => "Reactionset",query => $query});
}

sub getCompoundSet {
    my ($self,$query) = @_;
    return $self->getObject({type => "CompoundSet",query => $query});
}

sub getCompartment {
    my ($self, $query) = @_;
    return $self->getObject({ type => "Compartment", query => $query});
}

sub getObject {
	my ($self,$args) = @_;
	my $objects = $self->getObjects($args);
	return $objects->[0];
}

sub getObjects {
    my ($self,$args) = @_;
    my $type = $args->{type};
    my $query = $args->{query};
    if(!defined($type) || !defined($query) || ref($query) ne 'HASH') {
        # Calling utilities::ARGS takes ~ 10 microseconds
        # right now we are calling getObjects ~ 200,000 for biochem
        # initialization, so removing this shaves 2 seconds off start time.
    	ModelSEED::utilities::ERROR("Bad arguments to getObjects.");
    }
    # resultSet is a map of $object => $object
    my $resultSet;
    my $indices = $self->indices;
    while ( my ($attribute, $value) = each %$query ) {
        # Build the index if it does not already exist
        unless (defined($indices->{$type}) &&
                defined($indices->{$type}->{$attribute})) {
    		$self->buildIndex({type => $type, attribute => $attribute});
    	}
        my $index = $indices->{$type};
        my $newHits = $index->{$attribute}->{$value};
        # If any index returns empty, return empty.
        return [] if(!defined($newHits) || @$newHits == 0);
        # Build the current resultSet map $object => $object
        my $newResultSet = { map { $_ => $_ } @$newHits };
        if(!defined($resultSet)) {
            # Use the current result set if %resultSet is empty,
            # which will only happen on the first time through the loop.
            $resultSet = $newResultSet; 
            next;
        } else {
            # Otherwise we delete entries in our current $resultSet that
            # are not defined within the $newResultSet. By grepping and
            # deleting we can do this in-place in $resultSet
            delete $resultSet->{ grep { !defined($newResultSet->{$_}) } keys %$resultSet };
        }
    }
    return [values %$resultSet];
}

sub checkType {
	my ($self,$type) = @_;
	my $types = {
        compounds => "compounds",
    	Compound => "compounds",
    	reactions => "reactions",
    	Reaction => "reactions",
        media => "media",
    	Media => "media",
        compoudnSets => "compoundSets",
    	CompoundSet => "compoundSets",
        compoudnSets => "reactionSets",
    	ReactionSet => "reactionSets",
        compartments => "compartments",
        Compartment => "compartments",
    };
    if (!defined($types->{$type})) {
        die "Invalid Type";
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
		$self->indices({});
	} else {
		$self->checkType($args->{type});
		if (!defined($args->{attribute})) {
			$self->indices->{$args->{type}} = {};	
		} else {
			$self->indices->{$args->{type}}->{$args->{attribute}} = {};
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
		push(@{$self->indices->{$args->{type}}->{$attribute}->{$objects->[$i]->$attribute()}},$objects->[$i]);
	}
}

sub _buildindices { return {}; }
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }

__PACKAGE__->meta->make_immutable;
1;
