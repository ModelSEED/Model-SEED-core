package ModelSEED::Database::FileDB;

use Moose;
use namespace::autoclean;

use ModelSEED::Database::FileDB::KeyValueStore;


# with 'ModelSEED::Database';

my $uuid_regex =
  qr/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/;

my $user_type = 'user';
my $obj_types = ['biochemistry', 'annotation', 'mapping'];

has kvstore => (
    is  => 'rw',
    isa => 'ModelSEED::Database::FileDB::KeyValueStore',
    required => 1
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $kvstore = ModelSEED::Database::FileDB::KeyValueStore->new(@_);

    return { kvstore => $kvstore };
};

sub has_data {
    my ($self, $user, $refstring) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {
        # check if user exists
        return $self->kvstore->has_object('user', $user->{login});
    } else {

    }
}

sub get_data {
    my ($self, $user, $refstring) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {
        # get user
        return $self->kvstore->get_object('user', $user->{login});
    } else {

    }
}

sub save_data {
    my ($self, $user, $refstring, $data) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {
        # create user
        return $self->kvstore->save_object('user', $data);
    } else {

    }
}

sub delete_data {
    my ($self, $user, $refstring) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {
        # delete user
        return $self->kvstore->delete_object('user', $user->{login});
    } else {

    }
}

sub add_viewer {
    my ($self, $user, $refstring, $viewer) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {

    } else {

    }
}

sub remove_viewer {
    my ($self, $user, $refstring, $viewer) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {

    } else {

    }
}

sub set_public {
    my ($self, $user, $refstring, $public) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {

    } else {

    }
}

sub list_children {
    my ($self, $user, $refstring) = @_;

    $user = $self->_handle_user($user);
    my $ref = $self->_handle_refstring($refstring);

    if ($ref->{type} eq $user_type) {

    } else {

    }
}

sub _get_id_from_ref {
    my ($self, $ref) = @_;

=head

Possible Ref Structure
  1. { type => $type }
    Get all objects of type: $type that user can see
  2. { type => $type, id => { type => 'uuid', uuid => $uuid } }
    Get single object with uuid: $uuid
  3. { type => $type, id => { type => 'alias', user => $user } }
    Get all objects from $user alias space that the user can see
  4. { type => $type, id => { type => 'alias', user => $user, alias => $alias } }
    Get single object with alias $user/$alias

=cut


}

sub _handle_user {
    my ($self, $user) = @_;

    # do user stuff, for now just a string so return

    return {
        login => $user
    };
}

sub _handle_refstring {
    my ($self, $refstring) = @_;

    my @refs = split(/\./, $refstring);
    my $type = shift(@refs);
    if ($type eq $user_type) {
        # should users have permissions?
        if (@refs == 0) {
            # requesting all users
            return {
                type => $type
            }
        } elsif (@refs == 1) {
            return {
                type => $type,
                id   => $refs[0]
            };
        } else {
            # error
            die "Bad call";
        }
    } elsif (grep {$_ eq $type} @$obj_types) {
        # do type stuff
        if (@refs == 0) {
            # requesting all objects visible to the user
            # ex: 'biochem'
            return {
                type => $type
            }
        }

        my $id;
        my $user_or_uuid = shift(@refs);
        # check if uuid
        if ($user_or_uuid =~ $uuid_regex) {
            # ex: 'biochem.12345678-9012-3456-7890-123456789012'
            $id = {
                type => 'uuid',
                uuid => $user_or_uuid
            };
        } else {
            # assume it's a user
            # ex: 'biochem.paul'
            $id = {
                type => 'alias',
                user => $user_or_uuid
            };

            if (@refs > 0) {
                # ex: 'biochem.paul.main'
                $id->{alias} = shift(@refs);
            }
        }

        if (@refs == 0) {
            # return, no sub-types
            return {
                type => $type,
                id   => $id
            }
        }

        while (0) {
            # parse through subtypes and add
            # ex: 'biochem.paul.main.reactions'

            # TODO: implement
        }
    } else {
        # error
        die "Type ($type) not defined";
    }
}

1;
