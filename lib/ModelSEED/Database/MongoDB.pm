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
use ModelSEED::RefParse;

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

has refParse => (
    is => 'ro',
    isa => 'ModelSEED::RefParse',
    builder => '_buildRefParse',
    lazy => 1,
);


$ModelSEED::Database::MongoDB::aliasCollection = "aliases";

sub has_data {
    my ($self, $ref, $auth) = @_;
    my $refStruct = $self->refParse->parse($ref);
    my $collection = $self->_get_collection($refStruct);
    $query = $self->_mixin_auth_query($query, $auth->username, 'r');
    my $id = $refStruct->{id};
    my $username = $auth->username;
    my $o = $self->db->$collection->find_one({ aliases => $id });
    return 0 unless(defined($o->viewers->{$username}) || $o->{public});
    return (defined($o)) ? 1 : 0;
}

sub get_data {
    my ($self, $ref, $auth) = @_;
    my $refStruct = $self->refParse->parse($ref);
    # get the collection
    my $collection = $self->_get_collection($refStruct);
    # determine id type =>> query
    my $query = $self->_mixin_id_query({}, $refStruct);
    # determine ref => auth_type
    # if auth_type on this, auth =>> query
    # else: _get_auth(query)
    my $id = $refStruct->{id};
    my $username = $auth->username;
    my $o = $self->db->$collection->find_one({ aliases => $id });
    return (defined($o)) ? $o->{data} : undef;
}

sub save_data {
    my ($self, $type, $id, $object) = @_;
    my $old = $self->db->$type->find_one({ aliases => "$id" });
    # Remove old alias reference
    if(defined($old)) {
        $self->db->$type->update(
            {aliases => $id},
            {'$pull' => {aliases => "$id" }},
            {safe    => 0}
        );
        my $errObj = $self->db->last_error();
        unless (!defined($errObj->{err}) 
            && $errObj->{ok} 
            && $errObj->{n} == 1)
        {
            return 0;
        }
        # Push ancestry onto new object
        push(@{$object->{parents}}, $old->{data}->{uuid});
    }
    # Insert into database
    $self->db->$type->insert(
        {   aliases => [$id],
            data    => $object
        },
        {safe => 0}
    );
    my $errObj = $self->db->last_error();
    #return (!defined($errObj->{err}) && $errObj->{ok}) ? $errObj->{n} : 0;
    # For whatever reason $errObj->{n} is not correct
    return (!defined($errObj->{err}) && $errObj->{ok}) ? 1 : 0;
}

sub delete_object {
    my ($self, $type, $id) = @_;
    $self->db->$type->remove({ aliases => "$id" }, {safe => 0, just_one => 1});
    my $errObj = $self->db->last_error();
    return (!defined($errObj->{err}) && $errObj->{ok}) ? $errObj->{n} : 0;
}

sub find_objects {
    my ($self, $type, $query) = @_;
    my $cursor = $self->db->$type->find($query);
    return [ $cursor->all ];
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

sub _get_alias_permissions {
    my ($self, $type, $alias) = @_;
    my $aliasCollection = $ModelSEED::Database::MongoDB::aliasCollection;
    my $o = $self->db->$aliasCollection->find_one({ type => $type, alias => $alias });
    return $o;
}

sub _set_alias_permissions {
    my ($self, $type, $alias) = @_;
    
}
sub _get_collection {
    my ($self, $refParseStruct) = @_;
    my $map = $self->_collectionMap;
    my @base_types = @{$refParseStruct->{base_types}};
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

sub _mixin_id_query {
    my ($self, $query, $refStruct) = @_;
    my ($id, $type) = ($refStruct->{id}, $refStruct->{id_type});
    if($type eq 'uuid') {
        return $query->{uuid} = $id;
    } elsif($type eq 'alias') {
        return $query->{aliases} = $id;
    }
}

sub _buildRefParse {
    return ModelSEED::RefParse->new();
}


1;
