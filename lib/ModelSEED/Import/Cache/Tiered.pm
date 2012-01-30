package ModelSEED::Import::Cache::Tiered;
# This package implements a three tiered cache interface that
# should work across multiple processes. At the lowest level,
# we have a RoseDB SQL database that contains objects. This is
# accessible across processes.
#
# Next up from that is a BerkeleyDB key -> value store that
# is shared across proccesses. Keys are md5 hashes and values
# are JSON encoded "query objects" that can be unencoded and
# given to RoseDB via get_objects($type, $query).
#
# Finally, at the private process level, we have a size-restricted
# LRU hash of key -> value where key is the md5 hash and value is
# the RDB object in memory. This is cacheSize limited and configurable.
#
# Writes are always back to SQL while reads can come from any level.
# 
# Exposed interface:
#
#    get ( $type , $key )
#
#    set ( $type, $key, $object )
#
#
# Parameters:
#   
#    cacheSize - size of local cache, e.g. "2G", "200M".
#    directory - location of the BerkeleyDB on disk (required)
#    om        - ObjectManager (required)
#    importer  - ModelSEED::Import object (required)
#    types     - ArrayRef of types, e.g. [qw(compound reaction reagend)]
#               (requied)
#
use strict;
use warnings;
use Moose;
use BerkeleyDB;
use Cwd 'abs_path';
use JSON::XS qw(encode_json decode_json);
use Carp qw(confess);
use Tie::Cache;
use Try::Tiny;
extends 'ModelSEED::Import::Cache';

has 'directory' => (is => 'rw', isa => 'Str', required => 1);
has 'cacheSize' => (is => 'rw', isa => 'Str', default => '2G');
has 'debug' => ( is => 'rw', isa => 'Int', default => 0);

# internal parameters
has 'local' => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => '_buildLocal' );
has 'shared' => ( is => 'rw', isa => 'BerkeleyDB::Hash', lazy => 1, builder => '_buildShared' );
has 'shared_env' => ( is => 'rw', isa => 'BerkeleyDB::Env', lazy => 1, builder => '_buildSharedEnv');
has 'debug_stats' => ( is => 'rw', isa => 'HashRef', builder => '_buildStats', lazy => 1);

sub get {
    my ($self, $type, $key) = @_;
    return undef unless(defined($type) && defined($key));
    my $superkey = $self->superkey($type, $key);
    # try getting from local cache
    my $value = $self->local->{$superkey};
    if(defined($value)) {
        $self->debug_stats->{local}->{get}->{hit} += 1 if($self->debug);
        return $value;
    } elsif($self->debug) {
        $self->debug_stats->{local}->{get}->{miss} += 1 if($self->debug);
    }
    # try getting from shared cache 
    $self->shared->db_get($superkey, my $query);
    if(defined($query)) {
        $self->debug_stats->{shared}->{get}->{hit} += 1 if($self->debug);
        $value = $self->om->get_object($type, decode_json($query));
        return $value if defined($value);
    }
    return undef;
}

sub set {
    my ($self, $type, $key, $rdbobj) = @_;
    # try getting first
    my $val = $self->get($type, $key);
    return $val if(defined($val));
    # now try getting with locks
    my $lck = $self->shared->cds_lock();
    $val = $self->get($type, $key);
    if(defined($val)) {
        $self->debug_stats->{set_after_lock}->{hit} += 1 if($self->debug);
        $lck->cds_unlock;
        return $val 
    } 
    # unable to get it and still locked
    my $error;
    try {
        $rdbobj->save(); # save, add to remote, add to local
        my $superkey = $self->superkey($type, $key);
        my $query = $self->importer->makeQuery($type, $rdbobj);
        $self->shared->db_put($superkey, encode_json($query));
        $self->local->{$superkey} = $rdbobj;
        $self->debug_stats->{set_after_lock}->{miss} += 1 if($self->debug);
    } catch {
        warn "Died when trying to save object ($type):\n";
        $error = 1;
    };
    $lck->cds_unlock; # unlock cds now
    return ($error) ? undef : $rdbobj; 
}
        
sub superkey {
    my ($self, $type, $key) = @_;
    return "$type:$key";
}

sub standardSize {
    my ($self) = @_;
    my $size = $self->cacheSize;
    my $types = {
        k => 1024,
        m => 1048576 ,
        g => 1073741824,
    };
    if($size =~ /(\d+)([kmgKMG]{1})[b]{0,1}/) {
        my ($count, $type) = ($1, lc($2));
        my $suffix = $types->{$type};
        die "Unknown size $size!\n" unless($suffix);
        return $count*$suffix;
    } elsif($size =~ /^\d+$/) {
        return $size;
    } else {
        confess "Unknown size $size!\n";
    }
}

sub _buildSharedEnv {
    my ($self) = @_;
    my $dir = $self->directory;
    mkdir $dir unless(-d $dir);
    return BerkeleyDB::Env->new({-Home => $dir, -ErrFile => *STDERR,
        -Flags => DB_CREATE | DB_INIT_MPOOL | DB_INIT_CDB })
        or die "Cannot create ENV $! $BerkeleyDB::Error\n";
}
sub _buildShared {
    my ($self) = @_;
    my $env = $self->shared_env;
    my $dir = $self->directory;
    return BerkeleyDB::Hash->new({ -Env => $env,
        -Filename => "$dir/berkeley.db", -Flags => DB_CREATE,
        }) or die "Cannot create BerkeleyDB $! $BerkeleyDB::Error\n";
}
sub _buildLocal {
    my ($self) = @_;
    tie my %cache, 'Tie::Cache', { MaxBytes => $self->standardSize() };
    return \%cache;
}

sub _buildStats {
    my ($self) = @_;
    return { local => { get => { hit => 0, miss => 0 } },
             shared => { get => { hit => 0, miss => 0} },
             set_after_lock => { hit => 0, miss => 0 },
           };
}
1;
