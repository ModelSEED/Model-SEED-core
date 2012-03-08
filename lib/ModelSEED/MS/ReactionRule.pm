########################################################################
# ModelSEED::MS::ReactionRule - This is the moose object corresponding to the Role object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/4/2012
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::ReactionRuleTransport;
use ModelSEED::MS::Mapping;
package ModelSEED::MS::ReactionRule;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has mapping => (is => 'rw',isa => 'ModelSEED::MS::Mapping',weak_ref => 1);

#Attributes
has 'uuid'     => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has 'modDate'  => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has 'locked'       => (is => 'rw', isa => 'Int', default  => 0);
has 'reaction_uuid'   => (is => 'rw', isa => 'Str', default  => "");
has 'compartment_uuid'     => (is => 'rw',isa => 'Str',default  => "");
has 'direction'     => (is => 'rw',isa => 'Str',default  => "=");
has 'transprotonNature'     => (is => 'rw',isa => 'Str',default  => "");

#Subobjects
has 'reaction' => (is => 'rw', isa => 'ModelSEED::MS::Reaction',lazy => 1, builder => '_buildReaction');
has 'compartment' => (is => 'rw', isa => 'ModelSEED::MS::Compartment',lazy => 1, builder => '_buildCompartment');
has 'reactionRuleTransports' => (is => 'rw', isa => 'ArrayRef[ModelSEED::MS::ReactionRuleTransport]',default => sub {return [];});

#Constants
has 'dbAttributes' => ( is => 'ro', isa => 'ArrayRef[Str]', 
    builder => '_buildDbAttributes' );
has '_type' => (is => 'ro', isa => 'Str',default => "Complex");

#Internally maintained variables
has 'changed' => (is => 'rw', isa => 'Bool',default => 0);

sub BUILDARGS {
    my ($self,$params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    $params->{_type} = $params->{type};
    delete $params->{type};
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
			ruletransports => ["reactionRuleTransports","ModelSEED::MS::ReactionRuleTransport"],
		};
        my $order = ["ruletransports"];
        foreach my $name (@$order) {
            if (defined($rels->{$name})) {
	            my $values = $rels->{$name};
	            my $function = $subObjects->{$name}->[0];
	            my $class = $subObjects->{$name}->[1];
	            my $objects = [];
            	foreach my $data (@$values) {
	                $data->{mapping} = $self->mapping();
	                push(@$objects, $class->new($data));
	            }
		        $self->$function($objects);
            }
		}
        delete $params->{relationships}
    }
}

sub transportString {
    my ($self) = @_;
	my $transString = "";
	my $ruleTrans = $self->reactionRuleTransports();
	for (my $i=0; $i < @{$ruleTrans}; $i++) {
		if (length($transString) > 0) {
			$transString .= "|";	
		}
		my $sign = "";
		if ($ruleTrans->[$i]->isImport() == 1) {
			$sign = "-";	
		}
		$transString .= "(".$sign.$ruleTrans->[$i]->transportCoefficient().")".$ruleTrans->[$i]->compound()->id()."[".$ruleTrans->[$i]->compartment()->id().$ruleTrans->[$i]->compartmentIndex()."]"
	}
	return $transString;
}

sub serializeToDB {
    my ($self) = @_;
	my $data = { type => $self->_type };
	my $attributes = $self->dbAttributes();
	for (my $i=0; $i < @{$attributes}; $i++) {
		my $function = $attributes->[$i];
		$data->{attributes}->{$function} = $self->$function();
	}
	return $data;
}

sub _buildCompartment {
    my ($self) = @_;
	if (defined($self->mapping())) {
        my $cmp = $self->mapping()->biochemistry()->getCompartment({uuid => $self->compartment_uuid()});
        if (!defined($cmp)) {
        	ModelSEED::utilities::ERROR("Compartment ".$self->compartment_uuid." not found in biochemistry!");
        }
        return $cmp;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve compartment without biochemistry!");
    }
}

sub _buildReaction {
    my ($self) = @_;
	if (defined($self->mapping())) {
        my $rxn = $self->mapping()->biochemistry()->getReaction({uuid => $self->reaction_uuid()});
        if (!defined($rxn)) {
        	ModelSEED::utilities::ERROR("Reaction ".$self->reaction_uuid()." not found in biochemistry!");
        }
        return $rxn;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve reaction without biochemistry!");
    }
}

sub _buildDbAttributes {
    return [qw( uuid modDate locked reaction_uuid compartment_uuid direction transprotonNature )];
}
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now(); }

__PACKAGE__->meta->make_immutable;
1;
