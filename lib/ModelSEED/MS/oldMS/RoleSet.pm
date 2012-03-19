########################################################################
# ModelSEED::MS::Role - This is the moose object corresponding to the Role object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/4/2012
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Role;
use ModelSEED::MS::Mapping;
package ModelSEED::MS::RoleSet;
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
has 'public'   => (is => 'rw', isa => 'Int', default  => 0);
has 'name'     => (is => 'rw',isa => 'Str',default  => "");
has 'searchname'     => (is => 'rw',isa => 'Str',default  => "");
has 'class'     => (is => 'rw',isa => 'Str',default  => "");
has 'subclass'     => (is => 'rw',isa => 'Str',default  => "");
has 'type'     => (is => 'rw',isa => 'Str',default  => "");

#Subobjects
has 'roles' => (is => 'rw', isa => 'ArrayRef[ModelSEED::MS::Role]',default => sub {return [];});

#Constants
has 'dbAttributes' => ( is => 'ro', isa => 'ArrayRef[Str]', 
    builder => '_buildDbAttributes' );
has '_type' => (is => 'ro', isa => 'Str',default => "RoleSet");

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
    my ($self,$params) = @_;
    my $rels = $params->{relationships};
    if(defined($rels)) {
        if (defined($rels->{roles}) && defined($params->{mapping})) {
        	for (my $i=0; $i < @{$rels->{roles}}; $i++) {
        		my $role = $params->{mapping}->getRole($rels->{roles}->[$i]->{attributes}->{role_uuid});
        		if (!defined($role)) {
        			ModelSEED::utilities::ERROR("Mapping role ".$rels->{roles}->[$i]->{attributes}->{role_uuid}." not found in mapping!");
        		}
        		push(@{$self->roles()},$role);
        		$role->addRoleSet($self);
        	}
        }
        delete $params->{relationships};
    }
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
