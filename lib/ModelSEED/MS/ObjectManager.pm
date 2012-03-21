########################################################################
# ModelSEED::MS::ObjectManager - This is the moose object corresponding to the ObjectManager object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T05:05:02
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::FileDB::FileIndex;
package ModelSEED::MS::ObjectManager;
use Moose;

# ATTRIBUTES:
has user => (is => 'rw',isa => 'ModelSEED::MS::User',lazy => 1,builder => '_builduser');
has filedb => (is => 'rw',isa => 'ModelSEED::FileDB::FileIndex',lazy => 1,builder => '_buildfiledb');
has objects => (is => 'rw',isa => 'HashRef',default => sub{return{};});


# BUILDERS:
sub _buildfiledb { return ModelSEED::FileDB::FileIndex->new(); }
sub _builduser { 
	my ($self) = @_;
	return $self->authenticate("public","public");
}


# CONSTANTS:
sub _type { return 'ObjectManager'; }


# FUNCTIONS:
sub authenticate {
	my ($self,$username,$password) = @_;
	my $userData = $self->filedb()->authenticate({username => $username,password => $password});
	if (defined($userData)) {
		my $user = ModelSEED::MS::User->new($userData);
		$self->user($user);
		$self->clear();
	}
}

sub clear {
	my ($self,$uuid) = @_;
	if (defined($uuid)) {
		delete $self->objects()->{$uuid};
	} else {
		$self->objects({});
	}
}

sub get {
	my ($self,$uuid) = @_;
	if (!defined($self->objects()->{$uuid})) {
		$self->objects()->{$uuid} = $self->filedb()->get_object({uuid => $uuid,user => $self->user()->uuid()});	
	}
	return $self->objects()->{$uuid}; 
}

sub create {
	my ($self,$type,$args) = @_;
	my $class = "ModelSEED::MS::".$type;
	my $object = $class->new($args);
	$object->parent($self);
	$self->objects()->{$object->uuid()} = $object;
	return $object;
}

sub save {
	my ($self,$object) = @_;
	return $self->filedb()->save_object({user => $self->user()->uuid(),object => $object->serializeToDB()});
}

__PACKAGE__->meta->make_immutable;
1;
