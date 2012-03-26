########################################################################
# ModelSEED::MS::ObjectManager - This is the moose object corresponding to the ObjectManager object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T05:05:02
########################################################################
package ModelSEED::MS::ObjectManager;

use namespace::autoclean;
use ModelSEED::MS::User;
use Moose;

# ATTRIBUTES:
has db => (
    is       => 'rw',
    isa      => 'ModelSEED::Database',
    required => 1
);

has username => (
    is  => 'rw',
    isa => 'Str'
);

has password => (
    is       => 'rw',
    isa      => 'Str',
    required => 1
);

has user => (
    is       => 'rw',
    isa      => 'ModelSEED::MS::User',
    required => 1
);

has objects => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {}; }
);

sub BUILD {
    # authenticate username and password, and get the user object from database
    
}

# CONSTANTS:
sub _type { return 'ObjectManager'; }

# FUNCTIONS:
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
		$self->objects()->{$uuid} = $self->filedb()->get_object($type,{uuid => $uuid,user => $self->user()->login()});	
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
	return $self->filedb()->save_object($object->_type(),{user => $self->user()->login(),object => $object->serializeToDB()});
}

__PACKAGE__->meta->make_immutable;
1;
