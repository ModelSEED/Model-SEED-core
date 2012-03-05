package ModelSEED::MS::Annotation;

use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::utilities;
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
has genome_uuid => (is => 'rw', isa => 'Str', default => '');
has name        => (is => 'rw', isa => 'Str', default => '');

# Subobjects
#has features => (is => 'rw',isa => 'ArrayRef[ModelSEED::MS::Feature]',default => undef);
#has genome => (is => 'rw',isa => 'ModelSEED::MS::Genome',default => undef);

# Computed attributes
has indices => (is => 'rw',isa => 'HashRef',lazy => 1,builder => '_buildindices');

# Constants
has dbAttributes => (is => 'ro',isa => 'ArrayRef[Str]',builder => '_buildDbAttributes');
has _typesHash => (is => 'ro',isa => 'HashRef[Str]',builder => '_buildTypesHash');
has _type => (is => 'ro',isa => 'Str',default => 'Annotation');

sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
	if(defined($rels)) {
		#features|genome
        print "Annotation relations:".join("|",keys(%{$rels}))."\n";
    }
    return $params;
}

sub BUILD {
    my ($self, $params) = @_;
    my $rels = $params->{relationships};
}

sub printToFile {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{filename => undef});
	my $data = ["Attributes{"];
#	my $printedAtt = $self->_printedAtrributes();
#	for (my $i=0; $i < @{$printedAtt}; $i++) {
#		my $att = $printedAtt->[$i];
#		push(@{$data},$att."\t".$self->$att());
#	}
#	push(@{$data},"}");
#	push(@{$data},"Compartments{");
#	push(@{$data},"Compartment ID\tLabel\tpH\tPotential");
#	foreach my $compartment (@{$self->mdlcompartments()}) {
#		push(@{$data},$compartment->id()."\t".$compartment->label()."\t".$compartment->pH()."\t".$reaction->potential());
#	}
#	push(@{$data},"}");
#	push(@{$data},"Biomass{");
#	push(@{$data},"Biomass rxn\tBiomass cpd\tCoefficient\tCompartment");
#	foreach my $biomass (@{$self->mdlbiomass()}) {
#		foreach my $biomassCpd (@{$biomass->biomasscompounds()}) {
#			push(@{$data},$biomass->id()."\t".$biomassCpd->compound()."\t".$biomassCpd->coefficient()."\t".$biomassCpd->compartment()->id());
#		}
#	}
#	push(@{$data},"}");
#	push(@{$data},"Reactions{");
#	push(@{$data},"Reaction ID\tDirection\tCompartment\tProtons\tTransport\tGPR\tEquation");
#	foreach my $reaction (@{$self->mdlreactions()}) {
#		push(@{$data},$reaction->reaction()->id()."\t".$reaction->direction()."\t".$reaction->compartment()->id()."\t".$reaction->protons()."\t".$reaction->transport()."\t".$reaction->gprString()."\t".$reaction->equation());
#	}
	push(@{$data},"}");
	if (defined($args->{filename})) {
		ModelSEED::utilities::PRINTFILE($args->{filename},$data);
	}
	return $data;
}

######################################################################
#Query Functions
######################################################################
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

sub _printedAttributes { return [ qw( id name version type growth reactions annotations compounds status) ]; }
sub _buildTypesHash {
	return {
		Feature => "features"
    }; 
}

sub _buildDbAttributes { return [ qw( uuid name genome_uuid modDate locked ) ]; }
sub _buildindices { return {}; }
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }

__PACKAGE__->meta->make_immutable;
1;
