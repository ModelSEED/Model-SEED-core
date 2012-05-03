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

$ModelSEED::Database::MongoDB::METADATA = "__metadata__";
my $METADATA = $ModelSEED::Database::MongoDB::METADATA;

sub has_object {
    my ($self, $type, $id) = @_;
    my $o = $self->db->$type->find_one({ aliases => "$id" });
    return (defined($o)) ? 1 : 0;
}

sub get_object {
    my ($self, $type, $id) = @_;
    my $o = $self->db->$type->find_one({ aliases => "$id" });
    return (defined($o)) ? $o->{data} : undef;
}

sub save_object {
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

sub get_metadata {
    my ($self, $type, $id, $selection) = @_;
    my $o = $self->db->$type->find_one({ aliases => $id });
    return undef unless defined $o;
    my $meta = $o->{$METADATA};
    unless(defined($meta)) {
        $meta = $o->{$METADATA} = {};
    }
    my ($parent, $key) = _followPath($o, $selection, $METADATA);
    return $parent->{$key};
}

sub set_metadata {
    my ($self, $type, $id, $selection, $metadata) = @_;
    # Kludge for 'Overwrite metadata must provide hash
    return 0 if( $selection eq '' && ref($metadata) ne 'HASH');
    my $o = $self->db->$type->find_one({ aliases => $id });
    return 0 unless defined $o;
    my $meta = $o->{$METADATA};
    unless(defined($meta)) {
        $meta = $o->{$METADATA} = {};
    }
    my ($parent, $key) = _followPath($o, $selection, $METADATA);
    $parent->{$key} = $metadata;
    $self->db->$type->save($o, {safe => 0});
    my $errObj = $self->db->last_error();
    return (!defined($errObj->{err}) && $errObj->{ok}) ? $errObj->{n} : 0;
}

sub remove_metadata {
    my ($self, $type, $id, $selection) = @_;
    my $o = $self->db->$type->find_one({ aliases => $id });
    return 0 unless defined $o;
    my $meta = $o->{$METADATA};
    unless(defined($meta)) {
        $meta = $o->{$METADATA} = {};
    }
    my ($parent, $key) = _followPath($o, $selection, $METADATA);
    delete $parent->{$key};
    $self->db->$type->save($o);
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
1;
