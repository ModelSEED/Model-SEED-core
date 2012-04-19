package ModelSEED::PersistenceAPI;

use Moose;

use Try::Tiny;
use Digest::MD5 qw(md5_hex);
use JSON::Any;

use ModelSEED::Database;

my $RESERVED_META = "__system__";

has db        => ( is => 'rw', isa => 'ModelSEED::Database' );
has db_type   => ( is => 'rw', isa => 'Str', required => 1 );
has db_config => ( is => 'rw', isa => 'HashRef', required => 1 );

=head

TODO:
- implement get_object (get_data works)
- figure out method to get parents/ancestors

=cut

=head

constructor params

{
    db_type   => 'FileDB',
    db_config => {
	directory => '',
	filename => ''
    },
}

=cut

sub BUILD {
    my ($self) = @_;

    # get database connection
    my $db_mod = "ModelSEED::" . $self->db_type;
    my $db_req = $db_mod . ".pm";
    $db_req =~ s/::/\//g;

    try {
	require $db_req;
	$self->db($db_mod->new($self->db_config));
    } catch {
	die "Could not import database package: $db_mod";
    }
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

    return $self->db->get_object('user', $user);
}

sub delete_user {
    my ($self, $user) = @_;

    return $self->db->delete_object('user', $user);
}

=head
    is this method needed?

    has_object(user, type, alias);
=cut
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

=head
    get_object(user, type, alias);
=cut
sub get_object {
    my ($self, $user, $type, $user_alias) = @_;

    $type = lc($type);

    my $obj_data = $self->get_data($user, $type, $user_alias);
    # turn obj_data into object based on type
}

=head
    get_data(user, type, alias);
=cut
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

=head
    save_object(user, type, alias, object);
=cut
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

=head
    delete_object(user, type, alias);
=cut
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

=head
    get_aliases_for_type(user, type);
=cut
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
