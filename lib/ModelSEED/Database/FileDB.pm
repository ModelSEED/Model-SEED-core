package ModelSEED::Database::FileDB;

use Moose;
use namespace::autoclean;

use ModelSEED::Database::FileDB::KeyValueStore;

with 'ModelSEED::Database';

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
    my ($self, $ref, $auth) = @_;
    $ref = $self->_cast_ref($ref);
    my $uuid = $self->_get_uuid($ref, $auth);
    return 0 unless(defined($uuid));
    return $self->kvstore->has_object($uuid);
}

sub get_data {
    my ($self, $ref, $auth) = @_;
    $ref = $self->_cast_ref($ref);
    my $uuid = $self->_get_uuid($ref, $auth);
    return undef unless(defined($uuid));
    return $self->kvstore->get_object($uuid);
}

sub save_data {
    my ($self, $ref, $object, $auth) = @_;
    $ref = $self->_cast_ref($ref);
    my ($oldUUID, $update_alias);
    if ($ref->id_type eq 'alias') {
        $oldUUID = $self->_get_uuid($ref, $auth);
        # cannot write to alias not owned by callee
        return undef unless($auth->username eq $ref->alias_username);
    } elsif($ref->id_type eq 'uuid') {
        # cannot save to existing uuid
        if($self->has_data($ref, $auth)) {
             $oldUUID = $ref->id;
        }
    }
    if(defined($oldUUID)) {
        # We have an existing alias, so must:
        # - insert uuid in ancestors
        if(!defined($object->{ancestor_uuids})) {
            $object->{ancestor_uuids} = [];
        }
        my $found = 0;
        foreach my $uuid (@{$object->{ancestor_uuids}}) {
            if($uuid eq $oldUUID) {
                $found = 1;
                last;
            }
        }
        if(!$found) {
            push(@{$object->{ancestor_uuids}}, $oldUUID);
        }
        # - set to new UUID if that hasn't been done
        if($object->{uuid} eq $oldUUID) {
            $object->{uuid} = Data::UUID->new()->create_str();
        }
        # - update alias, but wait until after object write
        if($ref->id_type eq 'alias') {
            $update_alias = 1;
        }
    }

    # now do the saving
    $self->kvstore->save_object($object->{uuid}, $object);

    if($update_alias) {
        # update alias to new uuid
        my $rtv = $self->update_alias($ref, $object->{uuid}, $auth);
        return undef unless($rtv);
    } elsif(!defined($oldUUID) && $ref->id_type eq 'alias') {
        # alias is new, so create it
        my $alias = $self->_build_alias_meta($ref);
        my $info = {
            type => $ref->base_types->[0],
            alias => $ref->alias_string,
            uuid => $object->{uuid},
            owner => $auth->username,
            public => 0,
            viewers => {},
        };

        my $rtv = $self->kvstore->set_metadata('aliases', $alias, $info);
        return undef unless($rtv);
    }

    return $object->{uuid};
}

# not required, but probably should be
sub delete_data {
    # not yet
}

sub get_aliases {
    my ($self, $ref, $auth) = @_;

    my $query = {};
    if(defined($ref) && ref($ref) eq 'HASH') {
        $query = $ref;
    } elsif(defined($ref)) {
        $ref = $self->_cast_ref($ref);
        if($ref->type eq 'collection') {
            if(defined $ref->base_types->[0]) {
                $query->{type} = $ref->base_types->[0];
            }
            if($ref->has_owner) {
                $query->{owner} = $ref->owner;
            }
        } else {
            $query->{type} = $ref->base_types->[0];
            if ($ref->id_type eq 'uuid') {
                $query->{uuid} = $ref->id;
            }
            if ($ref->id_type eq 'alias') {
                $query->{alias} = $ref->alias_string;
                $query->{owner} = $ref->alias_username;
            }
        }
    }

    $query->{public} = 1 unless (defined($query->{public}) && ($query->{public} == 0));

    my $user = $auth->username;
    my $aliases = $self->kvstore->get_metadata('aliases');

    my $matched = [];
    foreach my $alias (keys %$aliases) {
        # match based on permissions
        my $info = $aliases->{$alias};
        if ($info->{owner} eq $user   ||
            $info->{viewers}->{$user} ||
            ($query->{public} && $info->{public})) {

            next if ($query->{type} && ($query->{type} ne $info->{type}));
            next if ($query->{owner} && ($query->{owner} ne $info->{owner}));
            next if ($query->{alias} && ($query->{alias} ne $info->{alias}));
            next if ($query->{uuid} && ($query->{uuid} ne $info->{uuid}));

            push(@$matched, $info);
        }
    }

    return $matched;
}

# not a required method... should it be?
sub alias_uuid {
    my ($self, $ref, $auth) = @_;

    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);

    if ($self->_check_permissions($auth->username, $info)) {
        return $info->{uuid};
    } else {
        return undef;
    }
}

sub alias_owner {
    my ($self, $ref, $auth) = @_;

    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);

    if ($self->_check_permissions($auth->username, $info)) {
        return $info->{owner};
    } else {
        return undef;
    }
}

sub alias_viewers {
    my ($self, $ref, $auth) = @_;

    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);

    if ($self->_check_permissions($auth->username, $info)) {
        my @viewers;
        map {push(@viewers, $_)} keys %{$info->{viewers}};

        return \@viewers;
    } else {
        return undef;
    }
}

sub alias_public {
    my ($self, $ref, $auth) = @_;

    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);

    if ($self->_check_permissions($auth->username, $info)) {
        return $info->{public};
    } else {
        return undef;
    }
}

sub update_alias {
    my ($self, $ref, $uuid, $auth) = @_;

    # can only update ref that is owned by caller
    return 0 unless($ref->alias_username eq $auth->username);

    # change alias to point to new uuid
    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);
    $info->{uuid} = $uuid;

    return $self->kvstore->set_metadata('aliases', $alias, $info);
}

sub add_viewer {
    my ($self, $ref, $viewerName, $auth) = @_;

    # can only update ref that is owned by caller
    return 0 unless($ref->alias_username eq $auth->username);

    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);
    $info->{viewers}->{$viewerName} = 1;

    return $self->kvstore->set_metadata('aliases', $alias, $info);
}

sub remove_viewer {
    my ($self, $ref, $viewerName, $auth) = @_;

    # can only update ref that is owned by caller
    return 0 unless($ref->alias_username eq $auth->username);

    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);
    delete $info->{viewers}->{$viewerName};

    return $self->kvstore->set_metadata('aliases', $alias, $info);
}

sub set_public {
    my ($self, $ref, $bool, $auth) = @_;

    # can only update ref that is owned by caller
    return 0 unless($ref->alias_username eq $auth->username);

    my $alias = $self->_build_alias_meta($ref);
    return undef unless $alias;

    my $info = $self->kvstore->get_metadata('aliases', $alias);
    return undef unless defined($info);
    $info->{public} = $bool;

    return $self->kvstore->set_metadata('aliases', $alias, $info);
}

# required, but not defined yet
sub find_data {
    # not yet
}

sub _check_permissions {
    my ($self, $user, $info) = @_;

    if ($user eq $info->{owner} ||
        $info->{public}         ||
        $info->{viewers}->{$user}) {
        return 1;
    } else {
        return 0;
    }
}

sub _get_uuid {
    my ($self, $ref, $auth) = @_;
    $ref = $self->_cast_ref($ref);
    if($ref->id_type eq 'alias') {
        return $self->alias_uuid($ref, $auth);
    } else {
        return $ref->id;
    }
}

sub _cast_ref {
    my ($self, $ref) = @_;
    if(ref($ref) && $ref->isa("ModelSEED::Reference")) {
        return $ref;
    } else {
        return ModelSEED::Reference->new(ref => $ref);
    }
}

sub _build_alias_meta {
    my ($self, $ref) = @_;

    my $t = $ref->base_types->[0];
    my $u = $ref->alias_username;
    my $a = $ref->alias_string;

    unless (defined($t) && defined($u) && defined($a)) {
        return 0;
    }

    return "$t/$u/$a";
}

1;
