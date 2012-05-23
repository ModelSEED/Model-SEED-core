########################################################################
# ModelSEED::Database::MongoDB - Impl. using MongoDB
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations: 
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#                       
# Date of module creation: 2012-05-02
########################################################################
package ModelSEED::Database::MongoDB;
use Moose;
use common::sense;

use MongoDB;
use MongoDB::Connection;
use MongoDB::Database;
use JSON::Path;
use ModelSEED::Reference;
use ModelSEED::MS::Metadata::Definitions;
use Data::Dumper;
use Clone qw(clone);

with 'ModelSEED::Database';
 
has db_name  => (is => 'ro', isa => 'Str', required => 1);
has host     => (is => 'ro', isa => 'Str');
has username => (is => 'ro', isa => 'Str');
has password => (is => 'ro', isa => 'Str');

# Internal attributes
has conn => (
    is        => 'ro',
    isa       => 'MongoDB::Connection',
    builder   => '_buildConn',
    lazy      => 1,
#    init_args => undef
);
has db => (
    is        => 'ro',
    isa       => 'MongoDB::Database',
    builder   => '_buildDb',
    lazy      => 1,
#    init_args => undef
);

has _collectionMap => (
    is      => 'ro',
    isa     => 'HashRef',
    builder => '_buildCollectionMap',
    lazy    => 1,
);

has split_rules => (
    is      => 'ro',
    isa     => 'HashRef',
    builder => '_build_split_rules',
    lazy    => 1
);


$ModelSEED::Database::MongoDB::aliasCollection = "aliases";

sub has_data {
    my ($self, $ref, $auth) = @_;
    my $uuid = $self->_get_uuid($ref, $auth);
    # TODO : Do we return undef for collection references?
    return 0 unless(defined($uuid));
    my $collection = $self->_get_collection($ref);
    my $o = $self->db->$collection->find_one({ uuid => $uuid });
    return (defined($o)) ? 1 : 0;
}

sub get_data {
    my ($self, $ref, $auth) = @_;
    my $uuid = $self->_get_uuid($ref, $auth);
    return undef unless(defined($uuid));
    my $collection = $self->_get_collection($ref);
    my $o = $self->db->$collection->find_one({ uuid => $uuid });
    return undef unless(defined($o));
    delete $o->{_id};
    return $self->_join_subobjects($ref, $o, $auth);
}

sub save_data {
    my ($self, $ref, $object, $auth) = @_;
    my ($oldUUID, $update_alias);
    $object = clone($object); # do this because we modify object
    if ($ref->id_type eq 'alias') {
        $oldUUID = $self->_get_uuid($ref, $auth);    
        # cannot write to alias not owned by callee
        return undef unless($auth->username eq $ref->alias_username);
    } elsif($ref->id_type eq 'uuid') {
        # cannot save to existing uuid
        return undef if(defined($self->get_data($ref, $auth)));
    }
    if(defined($oldUUID)) {
        # We have an existing alias, so must:
        # - insert uuid in ancestors
        if(defined($object->{ancestor_uuids})) {
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
        }
        # - set to new UUID if that hasn't been done
        if($object->{uuid} eq $oldUUID) {
            $object->{uuid} = Data::UUID->new()->create_str();
        }
        # - update alias, but wait until after object write
        $update_alias = 1;
    }
    # Now save object to collection
    $self->_split_object_for_save($ref, $object);
    if($update_alias) {
        # update alias to new uuid
        my $rtv = $self->update_alias($ref, $object->{uuid}, $auth);
        return undef unless($rtv);
    } elsif(!defined($oldUUID) && $ref->id_type eq 'alias') {
        # alias is new, so create it
        my $rtv = $self->create_alias($ref, $object->{uuid}, $auth);
        return undef unless($rtv);
    }
    return $object->{uuid};
}

sub _base_object_save {
    my ($self, $ref, $object) = @_;
    my $collection = $self->_get_collection($ref);
    $self->db->$collection->insert($object, {safe => 0});
    return undef if($self->_error);
    return 1;
}

sub _subobject_save {
    my ($self, $subobject, $subobject_rule, $parent_uuid) = @_;
    my $collection = $subobject_rule->{collection}; 
    my $parent_tag = $subobject_rule->{parent_tag};
    my $query =  {uuid => $subobject->{uuid}};
    $self->db->$collection->update($query,
        {'$addToSet' => {$parent_tag => $parent_uuid}},
    );
    if($self->_update_error(1)) {
        # no update, need to upsert object
        $subobject->{$parent_tag} = [$parent_uuid];
        $self->db->$collection->update($query, $subobject, {upsert => 1});
        if($self->_error) {
            return 0;
        }
        return 1;
    }
    return 1;
}

sub _subobject_get {
    my ($self, $subobject_rule, $parent_uuid) = @_;
    my $collection = $subobject_rule->{collection}; 
    my $parent_tag = $subobject_rule->{parent_tag};
    my $query =  { $parent_tag => $parent_uuid};
    my @objs = $self->db->$collection->find($query)->all;
    map { delete $_->{_id}; delete $_->{$parent_tag}; } @objs;
    return [@objs];
}


sub delete_data {
    my ($self, $ref, $auth) = @_;
    my $uuid = $self->_get_uuid($ref, $auth);
    return undef unless(defined($uuid));
    # TODO - do we actually want to delete objects?
    return 1;
}

sub find_data {
    my ($self, $type, $query) = @_;
}


sub _join_subobjects {
    my ($self, $ref, $base_object, $auth) = @_;
    # determine ref type
    my $type = $ref->base_types->[scalar(@{$ref->base_types}) - 1];
    my $rules = $self->split_rules->{$type};
    if(!defined($rules)) {
        die "Unknown type $type from ".$ref->ref;
    }
    my $parent_uuid = $base_object->{uuid};
    foreach my $attr (keys %$rules) {
        my $rule = $rules->{$attr};
        $base_object->{$attr} = $self->_subobject_get($rule, $parent_uuid);
    }
    return $base_object;
}

sub _split_object_for_save {
    my ($self, $ref, $object, $auth) = @_;
    # determine ref type
    my $type = $ref->base_types->[scalar(@{$ref->base_types}) - 1];
    my $rules = $self->split_rules->{$type};
    if(!defined($rules)) {
        die "Unknown type $type from ".$ref->ref;
    }
    my $parent_uuid = $object->{uuid};
    # split into subobjects
    foreach my $attr (keys %$rules) {
        my $rule = $rules->{$attr};
        if ( $rule->{type} eq 'array' ) {
            my $subobjects = $object->{$attr};
            $subobjects ||= [];
            foreach my $subobject (@$subobjects) {
                my $success = $self->_subobject_save($subobject, $rule, $parent_uuid);
                warn "Failed to save $attr : " . $subobject->{uuid} . "\n" unless($success);
            }
        }
        delete $object->{$attr};
    }
    return $self->_base_object_save($ref, $object);
}

sub _get_uuid {
    my ($self, $ref, $auth) = @_;
    if($ref->id_type eq 'alias') {
        return $self->alias_uuid($ref, $auth);
    } else {
        return $ref->id;
    }
}

sub _buildConn {
    my ($self) = @_;
    my $config = {
        db_name        => $self->db_name,
        auto_connect   => 1,
        auto_reconnect => 1
    };
    $config->{host} = $self->host if $self->host;
    $config->{username} = $self->username if $self->username;
    $config->{password} = $self->password if $self->password;
    my $conn = MongoDB::Connection->new(%$config);
    die "Unable to connect: $@" unless $conn;
    return $conn;
}

sub _buildDb {
    my ($self) = @_;
    my $db_name = $self->db_name;
    return $self->conn->$db_name;
}

sub _followPath {
    my ($object, $path, $root) = @_; 
    my @sections = split(/\./, $path);
    unshift @sections, $root;
    my $last = pop @sections;
    while ( my $target = shift @sections ) { 
        if($target eq '' || !defined($target)) {
            last;
        } elsif(ref($object) eq 'HASH') {
            # FIXME - Kludge, what to do if this.is.a.path is undef?
            if(!defined($object->{$target})) {
                $object->{$target} = {};
            }
            $object = $object->{$target};
        } elsif(ref($object) eq 'ARRAY') {
            for(my $i=0; $i<@$object; $i++) {
                $object = $object->[$i] if ($object->[$i] eq $target);
            }   
        } else {
            return undef;
        }   
    }   
    return ($object, $last);
}

sub _get_collection {
    my ($self, $ref) = @_;
    my $map = $self->_collectionMap;
    my @base_types = @{$ref->base_types};
    my $currentCollection = undef;
    while(@base_types) {
        my $type = shift @base_types;
        if(ref($map) eq 'HASH' && defined($map->{$type})) {
            $map = $map->{$type};
            $currentCollection = $type;
        } elsif ($map == 1) {
            return undef;
        }
    }
    return $currentCollection;
}

sub _buildCollectionMap {
    my ($self) = @_;
    return {
        'biochemistry' => {
            'reactions'    => 1,
            'compounds'    => 1,
            'media'        => 1,
            'compartments' => 1,
         },
    };
}

## Alias functions

sub _alias_update {
    my ($self, $ref, $update, $auth) = @_;
    # can only update ref that is an alias
    return 0 unless($ref->id_type eq 'alias');
    # can only update ref that is owned by caller
    return 0 unless($ref->alias_username eq $auth->username);
    my $aliasCollection = $ModelSEED::Database::MongoDB::aliasCollection;
    my $o = $self->db->$aliasCollection->update(
        {   alias => $ref->alias_string,
            type  => $ref->alias_type,
            owner => $auth->username,
        },
        # push viewer on viewers
        $update,
        {safe => 0}
    );
    return 0 if $self->_error;
    return 1;
}

sub _alias_query {
    my ($self, $ref, $attribute, $auth) = @_;
    # can only update ref that is an alias
    return undef unless($ref->id_type eq 'alias');
    my $aliasCollection = $ModelSEED::Database::MongoDB::aliasCollection;
    my $o = $self->db->$aliasCollection->find_one(
        {   alias => $ref->alias_string,
            type  => $ref->alias_type,
            owner => $ref->alias_username,
        }
    );
    # return undefined unless we are allowed to see alias
    #     either because it is (1) public, (2) owned by us
    #     or (3) we are in the list of viewers
    return undef unless(defined($o));
    unless($o->{public}
        || $o->{owner} eq $auth->username)
    {
        my $authorized = 0;
        foreach my $viewer (@{$o->{viewers}}) {
            if($viewer eq $auth->username) {
                $authorized = 1;
                last;
            }
        }
        return undef unless($authorized);
    }
    return $o->{$attribute};
}

sub create_alias {
    my ($self, $ref, $uuid, $auth) = @_;
    my $type = $ref->parent_collections->[0];
    my $validAliasTypes = {
        biochemistry => 1,
        model => 1,
        mapping => 1,
    };
    return 0 unless(defined($validAliasTypes->{$type}));
    return 0 unless($ref->id_type eq 'alias');
    return 0 unless($ref->alias_username eq $auth->username);
    my $obj = {
        type => $type,
        alias => $ref->alias_string,
        owner => $auth->username,
        public => 0,
        uuid => $uuid,
        viewers => [],
    };
    my $query = {
        type => $type,
        alias => $ref->alias_string,
        owner => $auth->username,
    };
    my $aliasCollection = $ModelSEED::Database::MongoDB::aliasCollection;
    $self->db->$aliasCollection->update($query, $obj, {upsert => 1});
    # this is 'upsert', which inserts one document if nothing matches
    return 0 if $self->_update_error(1);
    return 1;
}

sub alias_uuid {
    my ($self, $ref, $auth) = @_;
    return $self->_alias_query($ref, 'uuid', $auth);
}

sub alias_viewers {
    my ($self, $ref, $auth) = @_;
    return $self->_alias_query($ref, 'viewers', $auth);
}

sub alias_public {
    my ($self, $ref, $auth) = @_;
    return $self->_alias_query($ref, 'public', $auth);
}

sub alias_owner {
    my ($self, $ref, $auth) = @_;
    return $self->_alias_query($ref, 'owner', $auth);
}

sub update_alias {
    my ($self, $ref, $uuid, $auth) = @_;
    my $update = { '$set' => { 'uuid' => $uuid }};
    return $self->_alias_update($ref, $update, $auth);
}

sub remove_viewer {
    my ($self, $ref, $viewerName, $auth) = @_;
    my $update = { '$pull' => { 'viewers' => $viewerName }};
    return $self->_alias_update($ref, $update, $auth);
}

sub set_public {
    my ($self, $ref, $bool, $auth) = @_;
    my $update = { '$set' => { 'public' => $bool }};
    return $self->_alias_update($ref, $update, $auth);
}

sub add_viewer {
    my ($self, $ref, $viewerName, $auth) = @_;
    my $update = { '$push' => { 'viewers' => $viewerName }};
    return $self->_alias_update($ref, $update, $auth);
}

## MongoDB error checking functions
sub _error {
    my ($self, $count) = @_;
    my $errObj = $self->db->last_error();
    unless (!defined($errObj->{err}) && $errObj->{ok}) {
        return 1;
    }
    return 0;
}
sub _update_error {
    my ($self, $count) = @_;
    return 1 if $self->_error;
    my $e = $self->db->last_error();
    return 1 if $e->{n} != $count;
    return 0;
}
sub _build_split_rules {
    my ($self) = @_;
    my $defs = ModelSEED::MS::Metadata::Definitions::objectDefinitions();
    my $top_level_types = [
        grep { $defs->{$_}->{parents}->[0] eq 'ModelSEED::Store' }
            keys %$defs
    ];
    my $rules = {};
    foreach my $type (@$top_level_types) {
        my $lc_type = lc(substr($type,0,1)).substr($type,1);
        $rules->{$lc_type} = {};
        my $def = $defs->{$type};
        foreach my $subObj (@{$def->{subobjects}}) {
            my $sub_name = $subObj->{name};
            $rules->{$lc_type}->{$sub_name} = {
                collection => $sub_name,
                parent_tag => "_parent_$lc_type",
                type => "array"
            };

        }
    }
    return $rules;
}

1;
