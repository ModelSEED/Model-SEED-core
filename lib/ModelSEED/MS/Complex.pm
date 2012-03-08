########################################################################
# ModelSEED::MS::Complex - This is the moose object corresponding to the Role object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/4/2012
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Role;
use ModelSEED::MS::Mapping;
package ModelSEED::MS::Complex;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has mapping => (is => 'rw',isa => 'ModelSEED::MS::Mapping',weak_ref => 1);

#Attributes
has 'uuid'     => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has 'modDate'  => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has 'id'       => (is => 'rw', isa => 'Str', required => 1);
has 'locked'   => (is => 'rw', isa => 'Int', default  => 0);
has 'name'     => (is => 'rw',isa => 'Str',default  => "");
has 'searchname'     => (is => 'rw',isa => 'Str',default  => "");

#Subobjects
has 'complexRoles' => (is => 'rw', isa => 'ArrayRef[ModelSEED::MS::ComplexRole]',default => sub {return [];});
has 'reactionRules' => (is => 'rw', isa => 'ArrayRef[ModelSEED::MS::ReactionRule]',default => sub {return [];});

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
			complexRoles => ["complexroles","ModelSEED::MS::ComplexRole"],
		};
        my $order = ["complexRoles"];
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
		if (defined($params->{relationships}->{reactionrules}) && defined($self->mapping())) {
			foreach my $data (@{$params->{relationships}->{reactionrules}}) {
				if (defined($data->{attributes}->{reaction_rule_uuid})) {
					my $rxnrule = $self->mapping()->getReactionRule($data->{attributes}->{reaction_rule_uuid});
					if (!defined($rxnrule)) {
						ModelSEED::utilities::ERROR("Reaction rule ".$data->{attributes}->{reaction_rule_uuid}." not found in mapping ".$self->mapping()->uuid()."!");
					}
					push(@{$self->reactionRules()},$rxnrule);
				}
			}
		}
        delete $params->{relationships}
    }
}

sub ruleString {
    my ($self) = @_;
	my $ruleString = "";
	my $rules = $self->reactionRules();
	for (my $i=0; $i < @{$rules}; $i++) {
		if (length($ruleString) > 0) {
			$ruleString .= "|";	
		}
		$ruleString .= $rules->[$i]->uuid();
	}
	return $ruleString;
}

sub roleString {
    my ($self) = @_;
	my $roleString = "";
	my $roles = $self->complexRoles();
	for (my $i=0; $i < @{$roles}; $i++) {
		if (length($roleString) > 0) {
			$roleString .= "|";	
		}
		$roleString .= $roles->[$i]->role()->id().":".$roles->[$i]->optional().":".$roles->[$i]->type();
	}
	return $roleString;
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

sub _buildDbAttributes {
    return [qw( uuid id  name searchname feature_uuid modDate locked )];
}
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now(); }

__PACKAGE__->meta->make_immutable;
1;
