########################################################################
# ModelSEED::MS::ObjectManager - This is the moose object corresponding to the ObjectManager object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T05:05:02
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::FileDB;
use ModelSEED::MS::User;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
package ModelSEED::MS::ObjectManager;
use Moose;
use namespace::autoclean;

# ATTRIBUTES:
has db => ( is => 'rw', isa => 'ModelSEED::Database', required => 1 );
has username => ( is  => 'rw', isa => 'Str' );
has password => ( is => 'rw', isa => 'Str', required => 1 );
has user => ( is => 'rw', isa => 'ModelSEED::MS::User', lazy => 1, builder => '_builduser');
has objects => (is => 'rw', isa => 'HashRef', default => sub { return {}; } );
has selectedAliases => (is => 'rw', isa => 'HashRef', default => sub { return {}; } );

sub BUILD {
    # authenticate username and password, and get the user object from database  
}

# CONSTANTS:
sub _type { return 'ObjectManager'; }

# FUNCTIONS:
sub getSelectedAliases {
	my ($self,$aliasClass) = @_;
	if (!defined($aliasClass)) {
		ModelSEED::utilities::ERROR("The 'selectedAliases' function requires a 'aliasClass' as input!");	
	}
	if (!defined($self->selectedAliases()->{$aliasClass})) {
		return undef;	
	}
	return $self->selectedAliases()->{$aliasClass};
}

sub authenticate {
	my ($self,$username,$password) = @_;
	#my $userData = $self->filedb()->authenticate({username => $username,password => $password});
	my $userData = {
		login => "chenry",
		password => "password",
		email => "chenry\@mcs.anl.gov",
		firstname => "Christopher",
		lastname => "Henry"
	};
	if (defined($userData)) {
		my $user = ModelSEED::MS::User->new($userData);
		$self->user($user);
		$self->clear();
	}
}

sub _builduser {
	my ($self) = @_;
	my $userData = {
		login => "chenry",
		password => "password",
		email => "chenry\@mcs.anl.gov",
		firstname => "Christopher",
		lastname => "Henry"
	};
	return ModelSEED::MS::User->new($userData);
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
	my ($self,$type,$uuid) = @_;
	if (!defined($self->objects()->{$uuid})) {
		print $uuid."\n";
		$self->objects()->{$uuid} = $self->db()->get_object($type,{uuid => $uuid,user => $self->user()->login()});	
	}
	return $self->objects()->{$uuid};
}

sub create {
	my ($self,$type,$args) = @_;
	my $class = "ModelSEED::MS::".$type;
	if (!defined($args)) {
		$args = {};	
	}
	my $object = $class->new($args);
	$object->parent($self);
	$self->objects()->{$object->uuid()} = $object;
	return $object;
}

sub save {
	my ($self,$object) = @_;
	return $self->db()->save_object($object->_type(),{user => $self->user()->login(),object => $object->serializeToDB()});
}

__PACKAGE__->meta->make_immutable;
1;
