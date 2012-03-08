########################################################################
# ModelSEED::MS::ReactionRuleTransport - This is the moose object corresponding to the Role object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/4/2012
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Compound;
use ModelSEED::MS::ReactionRule;
use ModelSEED::MS::Mapping;
package ModelSEED::MS::ReactionRuleTransport;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has mapping => (is => 'rw',isa => 'ModelSEED::MS::Mapping',weak_ref => 1);

#Attributes
has 'reaction_rule_uuid'     => (is => 'rw', isa => 'Str', default  => "");
has 'compartmentIndex'  => (is => 'rw', isa => 'Int', default  => "");
has 'compartment_uuid'       => (is => 'rw', isa => 'Str', default  => "");
has 'compound_uuid'   => (is => 'rw', isa => 'Str', default  => "");
has 'reaction_uuid'   => (is => 'rw', isa => 'Str', default  => "");
has 'transportCoefficient'   => (is => 'rw', isa => 'Num', default  => 0);
has 'isImport'   => (is => 'rw', isa => 'Int', default  => 0);

#Subobjects
has 'compartment' => (is => 'rw', isa => 'ModelSEED::MS::Compartment',lazy => 1,builder => '_buildCompartment');
has 'compound' => (is => 'rw', isa => 'ModelSEED::MS::Compound',lazy => 1,builder => '_buildCompound');
has 'rule' => (is => 'rw', isa => 'ModelSEED::MS::ReactionRule',lazy => 1,builder => '_buildRule');

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

sub _buildCompound {
    my ($self) = @_;
	if (defined($self->mapping())) {
        my $cpd = $self->mapping()->biochemistry()->getCompound({uuid => $self->compound_uuid()});
        if (!defined($cpd)) {
        	ModelSEED::utilities::ERROR("Compound ".$self->compound_uuid." not found in biochemistry!");
        }
        return $cpd;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve compound without biochemistry!");
    }
}

sub _buildRule {
    my ($self) = @_;
	if (defined($self->mapping())) {
        my $rule = $self->mapping()->getReactionRule({uuid => $self->reaction_rule_uuid()});
        if (!defined($rule)) {
        	ModelSEED::utilities::ERROR("Reaction rule ".$self->reaction_rule_uuid." not found in mapping!");
        }
        return $rule;
    } else {
        ModelSEED::utilities::ERROR("Cannot retrieve reaction rule without mapping!");
    }
}

sub _buildDbAttributes {
    return [qw( reaction_rule_uuid compartmentIndex  compartment_uuid compound_uuid reaction_uuid transportCoefficient isImport )];
}
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now(); }

__PACKAGE__->meta->make_immutable;
1;
