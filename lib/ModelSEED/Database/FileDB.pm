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
    my ($user, $refstring) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub get_data {
    my ($user, $refstring) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub save_data {
    my ($user, $refstring, $data) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub delete_data {
    my ($user, $refstring) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub add_viewer {
    my ($user, $refstring, $viewer) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub remove_viewer {
    my ($user, $refstring, $viewer) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub set_public {
    my ($user, $refstring, $public) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub list_children {
    my ($user, $refstring) = @_;

    $user = _handle_user($user);
    my $ref = _handle_refstring($refstring);
}

sub _handle_user {
    my ($user) = @_;

    # do user stuff
}

sub _handle_refstring {
    my ($refstring) = @_;

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
