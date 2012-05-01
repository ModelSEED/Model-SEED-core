########################################################################
# ModelSEED::MS::ObjectManager - This is the moose object corresponding to the ObjectManager object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T05:05:02
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::PersistenceAPI;
use ModelSEED::MS::User;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
package ModelSEED::MS::ObjectManager;
use Moose;
use namespace::autoclean;

# ATTRIBUTES:
has username => ( is => 'rw', isa => 'Str', required => 1, default => 'public' );
has password => ( is => 'rw', isa => 'Str', required => 1, default => 'public' );
has api => ( is => 'rw', isa => 'ModelSEED::PersistenceAPI', required => 1 );

has user => ( is => 'rw', isa => 'ModelSEED::MS::User', required => 0 );
has selectedAliases => (is => 'rw', isa => 'HashRef', default => sub { return {}; } );

sub BUILD {
    # authenticate username and password, and get the user object from database  
    my ($self) = @_;

    my $pass = $self->password();
    $self->password('########');

    my $user;
    if ($self->username eq 'public') {
	$user = ModelSEED::MS::User->new({
	    login => 'public',
	    password => 'public'
        });
    } else {
	my $user_hash = $self->api->get_user($self->username);
	if (!defined($user_hash)) {
	    die "User does not exist: " . $self->username;
	}

	$user = ModelSEED::MS::User->new($user_hash);

	# authenticate
	if (crypt($pass, $user->password) ne $user->password) {
	    die "Incorrect password";
	}
    }

    $self->user($user);
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

sub get {
	my ($self, $type, $alias) = @_;

	my $class = "ModelSEED::MS::".$type;

	my $obj = $self->api->get_object($self->username, $type, $alias);
	if (!defined($obj)) {
	    # handle error
	}

	return $class->new($obj);
}

sub create {
	my ($self, $type, $args) = @_;
	my $class = "ModelSEED::MS::".$type;
	if (!defined($args)) {
		$args = {};	
	}
	my $object = $class->new($args);
	$object->parent($self);
	return $object;
}

sub save {
	my ($self, $type, $alias, $object) = @_;
	return $self->api->save_object($self->username, $type, $alias, $object->serializeToDB());
}

__PACKAGE__->meta->make_immutable;
1;
