package ModelSEED::MS::Model;

use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::utilities;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Biomass;
use ModelSEED::MS::ModelCompartment;
use ModelSEED::MS::ModelReaction;
use ModelSEED::MS::ModelFBA;
use Carp qw(cluck);
use namespace::autoclean;
use DateTime;
use Data::UUID;

#Parent object link
has om => (is => 'rw', isa => 'ModelSEED::CoreApi');

#Attributes
has uuid        => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has modDate     => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has locked      => (is => 'rw', isa => 'Int', default => 0);
has public      => (is => 'rw', isa => 'Int', default => 1);
has id          => (is => 'rw', isa => 'Str', default => '');
has name        => (is => 'rw', isa => 'Str', default => '');
has version     => (is => 'rw', isa => 'Int', default => 0);
has type        => (is => 'rw', isa => 'Str', default => '');
has status      => (is => 'rw', isa => 'Str', default => '');
has reactions   => (is => 'rw', isa => 'Int', default => 0);
has compounds   => (is => 'rw', isa => 'Int', default => 0);
has annotations => (is => 'rw', isa => 'Int', default => 0);
has growth      => (is => 'rw', isa => 'Num', default => 0);
has current     => (is => 'rw', isa => 'Int', default => 0);
has aliases     => (is => 'rw', isa => 'HashRef', default => sub { return {}; });

# Subobjects
has biochemistry => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry');
has mapping => (is => 'rw',isa => 'ModelSEED::MS::Mapping');
has annotation => (is => 'rw',isa => 'ModelSEED::MS::Annotation');
has mdlcompartments => (
    is      => 'rw', default => sub { return []; },
    isa     => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelCompartment]'
);
has mdlbiomass => (
    is      => 'rw', default => sub { return []; },
    isa     => 'ArrayRef|ArrayRef[ModelSEED::MS::Biomass]'
);
#has mdlcompounds => (
#    is      => 'rw', default => sub { return []; },
#    isa     => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelCompound]'
#);
has mdlreactions => (
    is      => 'rw', default => sub { return []; },
    isa     => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelReaction]'
);
has modelfbas => (
    is      => 'rw', default => sub { return []; },
    isa     => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelFBA]'
);

# Computed attributes
has indices => (is => 'rw',isa => 'HashRef',lazy => 1,builder => '_buildindices');

# Constants
has dbAttributes => (is => 'ro',isa => 'ArrayRef[Str]',builder => '_buildDbAttributes');
has _typesHash => (is => 'ro',isa => 'HashRef[Str]',builder => '_buildTypesHash');
has _type => (is => 'ro',isa => 'Str',default => 'Model');

#Internally maintained variables
has changed => (is => 'rw', isa => 'Bool', default => 0);

sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
	if(defined($rels->{aliases})) {
		foreach my $alias (@{$rels->{aliases} || []}) {
			push(@{$params->{aliases}->{$alias->{attributes}->{type}}},$alias->{attributes}->{alias});
		}
    }
    return $params;
}

sub BUILD {
    my ($self, $params) = @_;
    my $rels = $params->{relationships};
    if(defined($rels)) {
		my $subObjects = {
			biochemistry => ["biochemistry","ModelSEED::MS::Biochemistry"],
		    annotation => ["annotation","ModelSEED::MS::Annotation"],
		    mapping => ["mapping","ModelSEED::MS::Mapping"],
			compartments => ["mdlcompartments","ModelSEED::MS::ModelCompartment"],
			biomass => ["mdlbiomass","ModelSEED::MS::Biomass"],
			reactions => ["mdlreactions","ModelSEED::MS::ModelReaction"],
			modelfbas => ["modelfbas","ModelSEED::MS::FBAResults"]
		};
        my $order = [qw(biochemistry annotation mapping compartments biomass reactions modelfbas)];
        foreach my $name (@$order) {
            if (defined($rels->{$name})) {
	            my $values = $rels->{$name};
	            my $function = $subObjects->{$name}->[0];
	            my $class = $subObjects->{$name}->[1];
	            my $objects = [];
	            if (ref($values) eq "ARRAY") {
	            	foreach my $data (@$values) {
		                $data->{model} = $self;
		                push(@$objects, $class->new($data));
		            }
		            $self->$function($objects);
	            } else {
	            	$objects->[0] = $class->new($values);
	            	$self->$function($objects->[0]);
	            }
            }
		}
        delete $params->{relationships}
    }
}

sub printToFile {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{filename => undef});
	my $data = ["Attributes{"];
	my $printedAtt = $self->_printedAttributes();
	for (my $i=0; $i < @{$printedAtt}; $i++) {
		my $att = $printedAtt->[$i];
		push(@{$data},$att."\t".$self->$att());
	}
	push(@{$data},"}");
	push(@{$data},"Compartments{");
	push(@{$data},"Compartment ID\tLabel\tpH\tPotential");
	foreach my $compartment (@{$self->mdlcompartments()}) {
		push(@{$data},$compartment->id()."\t".$compartment->label()."\t".$compartment->pH()."\t".$compartment->potential());
	}
	push(@{$data},"}");
	push(@{$data},"Biomass{");
	push(@{$data},"Biomass rxn\tBiomass cpd\tCoefficient\tCompartment");
	foreach my $biomass (@{$self->mdlbiomass()}) {
		foreach my $biomassCpd (@{$biomass->biomasscompounds()}) {
			push(@{$data},$biomass->id()."\t".$biomassCpd->compound()->id()."\t".$biomassCpd->coefficient()."\t".$biomassCpd->compartment()->id());
		}
	}
	push(@{$data},"}");
	push(@{$data},"Reactions{");
	push(@{$data},"Reaction ID\tDirection\tCompartment\tProtons\tGPR\tEquation");
	foreach my $reaction (@{$self->mdlreactions()}) {
		push(@{$data},$reaction->reaction()->id()."\t".$reaction->direction()."\t".$reaction->compartment()->id()."\t".$reaction->protons()."\t".join("|",@{$reaction->gpr()})."\t".$reaction->equation());
	}
	push(@{$data},"}");
	if (defined($args->{filename})) {
		ModelSEED::utilities::PRINTFILE($args->{filename},$data);
	}
	return $data;
}

######################################################################
#Query Functions
######################################################################
sub getModelCompartment {
    my ($self,$query) = @_;
    return $self->getObject("ModelCompartment",$query);
}

sub getModelReaction {
    my ($self,$query) = @_;
    return $self->getObject("ModelReaction",$query);
}

sub getBiomass {
    my ($self,$query) = @_;
    return $self->getObject("Biomass",$query);
}

sub getModelFBA {
    my ($self,$query) = @_;
    return $self->getObject("ModelFBA",$query);
}

sub getObject {
	my ($self,$type,$query) = @_;
	my $objects = $self->getObjects($type,$query);
	return $objects->[0];
}

sub getObjects {
    my ($self,$type,$query) = @_;
    if (!defined($type)) {
    	ModelSEED::utilities::ERROR("Cannot call function without specifying type!");
    }
    $type = $self->checkType($type);
    if (!defined($query)) {
    	my $newArray;
    	push(@{$newArray},@{$self->$type()});
    	return $newArray;
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
	my $typesHash = $self->_typesHash();
    if (!defined($typesHash->{$type})) {
        ModelSEED::utilities::ERROR("Invalid type: ".$type);
    }
    return $typesHash->{$type};
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
######################################################################
#Object algorithms
######################################################################
sub priceReconstruction {
	my ($self,$args) = @_;
#	Biochemistry
#	Reaction liklihood calculated from sequence
#	Compatments
#	Media
#	Growth data
#	 => Call to C++
#	List reaction IDs
#	reaction confidence?
#	transport stoichiometry
#	reaction GPR
#	reaction directionality
#	reaction compartments
#	annotation
	#Your code goes here using swig?
}

sub _printedAttributes { return [ qw( id name version type growth reactions annotations compounds status) ]; }
sub _buildTypesHash {
	return {
		mdlcompartments => "mdlcompartments",
		ModelCompartment => "mdlcompartments",
		ModelReaction => "mdlreactions",
		Biomass => "mdlbiomass",
		ModelFBA => "mdlfba"
    }; 
}
sub _buildDbAttributes { return [ qw( uuid id name version type growth reactions annotations compounds status  public current modDate locked ) ]; }
sub _buildindices { return {}; }
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }

__PACKAGE__->meta->make_immutable;
1;
