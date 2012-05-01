########################################################################
# ModelSEED::Store::Private - Base storage interface layer
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: 
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#                       
# Date of module creation: 2012-05-01
########################################################################
=pod

=head1 NAME

ModelSEED::Store - Base storage interface layer

=head1 NOTE

DO NOT USE Directly! This class has a complete, unauthenticated
access to the datastore. While the datastore is designed to limit
the visibility of objects to particular users, this class does
nothing to prevent people from accessing data. The "user" is passed
into each API function, therefore there is no assumption of security
when using this interface.  Use C<ModelSEED::Store> instead.

=head1 Initialization

=head2 new

    my $PStore = ModelSEED::Store::Private->new(\%)

Initialize a private storage interface object. This accepts a hash
reference to configuration details. There are no current configuration
options.

=head1 User Functions

These functions manipulate user objects within the storage layer.
Since a user must be defined for almost every call into the storage
interface, these functions are critical to add, remove or inspect
user objects.

=head2 create_user

    $PStore->create_user($username, \%);

Creates a user object. C<$username> is a unique string representing
the user's login name. C<\%> is a hashref containing user information.
This should really be the contents of C<ModelSEED::MS::User>.


=head2 get_user

    $PStore->get_user($username);

Returns a C<ModelSEED::MS::User> object. If no user is found, returns
C<undef>.

=head2 delete_user

    $PStore->delete_user($username);

Removes the user object from the storage interface. Not that this
has wide-ranging affects; that user will no longer be able to access
objects within the Store. This does not delete objects owned by that
user, however.

=head1 Object Methods 

These functions deal with checking for the existence of, getting
and saving objects. In most cases, objects are assumed to be instances
of classes under the C<ModelSEED::MS> hierarchy. For each of these
functions, C<$username> is the user's login name, a string. C<$type>
is a string representing the type of the object, e.g. "biochemistry".
C<$alias> is a string, representing a unique pointer to an object
in the datastore.  These generally have the form
C<"$username/arbitraryString">.


=head2 has_object

    $ps->has_object($username, $type, $alias);

Returns a boolean, true if the the object exists in the datastore.

=head2 get_object

    $ps->get_object($username, $type, $alias);

Returns a C<ModelSEED::MS> object of the type C<$type> or
C<undef> if no object exists.

=head2 save_object

    $ps->save_object($username, $type, $alias, $object);

Saves C<$object>, a C<ModelSEED::MS> object of the correct C<$type>
to the datastore at C<$alias>. Note that if there was an object
already at C<$alias>, this does not overwrite that object, but
changes the reference C<$alias> to point to the new object, C<$object>.

=head2 delete_object

    $ps->delete_object($username, $type, $alias);

Removes the alias pointer C<$alias> that points to an object in
the datastore. This does not actually remove the object, but it will
no longer be accessible via that alias.

=head1 Data Methods

These methods are like the Object Methods, except that they
return raw Perl data-structures instead of C<ModelSEED::MS> objects.


=head2 get_data

    $ps->get_data($username, $type, $alias);

Same as C<get_object> except that it is not marshaled into an object.


=head1 Querying

Getting a specific object is good, but sometimes we need to query what
objects are available. These functions allow for different types of
queries against the data store.

=head2 get_aliases_for_type

    $ps->get_aliases_for_type($username, $type);

=head1 Permissions: Editing and Viewing

Permissions are handled via the "alias" attribute and the following
functions. As an overview, any object with an alias like
C<"$username/aribtraryString> is "owned" by C<$username>. That
user may perform a C<save_object> call against the alias. No other
users may do this. So we have single-user write-access to objects.

For visibility, by default an object is only visible by the owner.
However, using the following functions, an owner may extend visibility
to other users. Finally, an object may be "public", visible to all
users.

=head2 add_viewer

    $ps->add_viewer($username, $type, $alias, $viewerUsername);

C<$username> must be the owner of the object of C<$type>, C<$alias>.
This extends viewing permissions to C<$viewerUsername>.

=head2 remove_viewer

    $ps->remove_viewer($username, $type, $alias, $viewerUsername);

C<$username> must be the owner of the object of C<$type>, C<$alias>.
This retracts viewing permissions to C<$viewerUsername>.

=head2 set_public

    $ps->set_public($username, $type, $alias, $bool);

C<$username> must be the owner of the object of C<$type>, C<$alias>.
This sets the public bit of the object to C<$bool>.

=cut
package ModelSEED::Store::Private;
use Moose;
use Try::Tiny;
use Digest::MD5 qw(md5_hex);
use JSON::Any;
use ModelSEED::Configuration;
use Moose::Util::TypeConstraints;
use Class::Autouse qw(
    ModelSEED::MS::User
);

my $RESERVED_META = "__system__";

role_type 'ModelSEED::Database';

has databases => ( is => 'rw', isa => 'ArrayRef' );
has db        => ( is => 'rw', isa => 'ModelSEED::Database' );

sub BUILD {
    my ($self) = @_;
    my $Config = ModelSEED::Configuration->new();
    my $stores = $Config->config->{stores} || [];
    my $databases = [];
    die "No storage defined!" unless(@$stores);
    foreach my $store (@$stores) {
        # get database connection
        my $db_class = $store->{class};
        my $db_req = $db_class . ".pm";
        $db_req =~ s/::/\//g;
        try {
            require $db_req;
            push(@$databases, $db_class->new($store));
        } catch {
            die "Could not import database package: $db_class";
        };
    }
    $self->databases($databases);
    $self->db($databases->[0]);
}

sub create_user {
    my ($self, $user, $object) = @_;

    unless ($self->db->save_object('user', $user, $object)) {
    return 0;
    }

    # now save type meta
    my $meta_path = "$RESERVED_META.type";
    $self->db->set_metadata('user', $user, $meta_path, 'user');

    return 1;
}

sub get_user {
    my ($self, $user) = @_;
    my $data = $self->db->get_object('user', $user);
    return undef unless(defined($data));
    return ModelSEED::MS::User->new($data);
}

sub delete_user {
    my ($self, $user) = @_;

    return $self->db->delete_object('user', $user);
}

sub has_object {
    my ($self, $user, $type, $user_alias) = @_;

    $type = lc($type);

    # split user from alias (paul/main)
    my ($alias_user, $alias) = _split_alias($user_alias);

    # get permissions for alias
    my $meta_path = "$RESERVED_META.aliases.$alias";
    my $info = $self->db->get_metadata('user', $alias_user, $meta_path);
    unless (defined($info)) {
    # no object, return false
    return 0;
    }

    # check permissions
    unless ($user eq $alias_user ||
        $info->{public}      ||
        $info->{viewers}->{$user}) {
    return 0;
    }

    return 1;
}

sub get_object {
    my ($self, $user, $type, $user_alias) = @_;
    $type = lc($type);
    my $obj_data = $self->get_data($user, $type, $user_alias);
    my $classBase = uc(substr($type,0,1)) . substr($type,1);
    my $class = "ModelSEED::MS::".$classBase;
    return $class->new($obj_data);
}

sub get_data {
    my ($self, $user, $type, $user_alias) = @_;

    $type = lc($type);

    # split user from alias (paul/main)
    my ($alias_user, $alias) = _split_alias($user_alias);

    # get permissions for alias
    my $meta_path = "$RESERVED_META.aliases.$alias";
    my $info = $self->db->get_metadata('user', $alias_user, $meta_path);
    unless (defined($info)) {
    # no object, return undef
    return;
    }

    # check permissions
    unless ($user eq $alias_user ||
        $info->{public}      ||
        $info->{viewers}->{$user}) {
    return;
    }

    my $obj_id = $info->{object};
    return $self->db->get_object($type, $obj_id);
}

sub save_object {
    my ($self, $user, $type, $user_alias, $object) = @_;

    $type = lc($type);

    # TODO: error checking on db call return values

    # split user from alias (paul/main)
    my ($alias_user, $alias) = _split_alias($user_alias);
    unless ($user eq $alias_user) {
    # cannot save to someone else's alias space
    return 0;
    }

    # save data, unless object already exists (check via md5)
    my $json_obj = _encode($object);
    my $md5 = md5_hex($json_obj);
    my $new = 0;
    unless ($self->db->has_object($type, $md5)) {
    $new = 1;
    $self->db->save_object($type, $md5, $json_obj);

    # now save type meta
    my $obj_meta = {
        type    => $type,
        parents => []
    };

    my $meta_path = "$RESERVED_META";
    $self->db->set_metadata($type, $md5, $meta_path, $obj_meta);
    }

    # now save the alias
    my $meta_path = "$RESERVED_META.aliases.$alias";
    my $info = $self->db->get_metadata('user', $user, $meta_path);
    if (defined($info)) {
    # update alias to point to new object
    $self->db->set_metadata('user', $user, "$meta_path.object", $md5);

    # get current list of parents and add parent obj
    my $parents = $self->db->get_metadata($type, $md5, "$RESERVED_META.parents");
    push(@$parents, $info->{object});
    $self->db->set_metadata($type, $md5, "$RESERVED_META.parents", $parents);
    } else {
    # create new alias and permissions
    $self->db->set_metadata('user', $user, $meta_path, {
        object  => $md5,
        type    => $type,
        public  => 0,
        viewers => {}
    });
    }

    return 1;
}

sub delete_object {
    my ($self, $user, $type, $user_alias) = @_;

    $type = lc($type);

    # split user from alias (paul/main)
    my ($alias_user, $alias) = _split_alias($user_alias);
    unless ($user eq $alias_user) {
    # cannot delete from someone else's alias space
    return 0;
    }

    my $meta_path = "$RESERVED_META.aliases.$alias";
    $self->db->remove_metadata($type, $user, $meta_path);
}

sub get_aliases_for_type {
    my ($self, $user, $type) = @_;

    $type = lc($type);

    # get user aliases
    my $meta_path = "$RESERVED_META.aliases";
    my $alias_hash = $self->db->get_metadata($type, $user, $meta_path);

    my $aliases = [];
    foreach my $alias (keys %$alias_hash) {
    if ($alias_hash->{$alias}->{type} eq $type) {
        push(@$aliases, $alias);
    }
    }

    return $aliases;
}

sub add_viewer {
    my ($self, $user, $type, $user_alias, $viewer) = @_;

    $type = lc($type);

    # split user from alias (paul/main)
    my ($alias_user, $alias) = _split_alias($user_alias);
    unless ($user eq $alias_user) {
    # can only change viewers if you own the object
    return 0;
    }

    my $meta_path = "$RESERVED_META.aliases.$alias.viewers.$viewer";
    return $self->db->set_metadata($type, $user, $meta_path, 1);
}

sub remove_viewer {
    my ($self, $user, $type, $user_alias, $viewer) = @_;

    $type = lc($type);

    # split user from alias (paul/main)
    my ($alias_user, $alias) = _split_alias($user_alias);
    unless ($user eq $alias_user) {
    # can only change viewers if you own the object
    return 0;
    }

    my $meta_path = "$RESERVED_META.aliases.$alias.viewers.$viewer";
    return $self->db->remove_metadata($type, $user, $meta_path);
}

sub set_public {
    my ($self, $user, $type, $user_alias, $public) = @_;

    unless ($public == 0 || $public == 1) {
    return 0;
    }

    $type = lc($type);

    # split user from alias (paul/main)
    my ($alias_user, $alias) = _split_alias($user_alias);
    unless ($user eq $alias_user) {
    # can only change viewers if you own the object
    return 0;
    }

    my $meta_path = "$RESERVED_META.aliases.$alias.public";
    return $self->db->set_metadata($type, $user, $meta_path, $public);
}

# split alias (paul/main) into user (paul) and alias (main)
sub _split_alias {
    my ($alias) = @_;

    my @alias_info = split('/', $alias);
    my $user = shift(@alias_info);
    $alias = join('/', @alias_info);

    return ($user, $alias);
}

sub _encode {
    my ($data) = @_;

    return JSON::Any->encode($data);
}

sub _decode {
    my ($data) = @_;

    return JSON::Any->decode($data);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
