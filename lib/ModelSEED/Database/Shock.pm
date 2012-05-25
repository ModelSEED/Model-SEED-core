########################################################################
# ModelSEED::Database::Shock - Impl. using Shock 
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations: 
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#                       
# Date of module creation: 2012-05-15
########################################################################

# TODO:
#  - wait until we get mutable metadata on storage objects
#  - because we can't save with it as it stands...

package ModelSEED::Database::Shock;
use Moose;
use common::sense;

use JSON::Path;
use JSON;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use Data::Dumper;
use URI::Split qw(uri_split uri_join);

with 'ModelSEED::Database';

has host => ( is => 'ro', isa => 'Str', required => 1 );
has port => ( is => 'ro', isa => 'Int', default => 8000 );

$ModelSEED::Database::Shock::TIMEOUT = 30;

# Internal attributes
has ua => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    builder => '_buildUA'
);
has json => (
    is => 'rw',
    isa => 'JSON',
    lazy => 1,
    builder => '_buildJSON',
);

sub has_object {
    my ($self, $type, $id, $auth) = @_;
    my $d;
    if($type eq 'user') {
        $d = $self->_makeRequest("GET", "/user/$id", undef, $auth);
    } else {
        $d = $self->_makeRequest("GET", "/node/$type-$id", undef, $auth);
    }
    return 0 unless defined($d);
    return ($d->{"E"} eq 404) ? 0 : 1;
}

sub get_object {
    my ($self, $type, $id, $auth) = @_;
    my $d;
    my $username;
    if($type eq 'user') {
        $d = $self->_makeRequest("GET", "/user/$id", undef, $auth);
    } else {
        $d = $self->_makeRequest("GET", "/node/$type-$id", undef, $auth);
    }
    return undef unless defined($d);
    return undef if($d->{"E"} eq 404);
    return $d->{D};

}
sub save_object {
    my ($self, $type, $id, $auth) = @_;
    my $username; 
    if($type eq 'user') {
        return undef;
    } else {
        my $d = $self->_makeRequest("PUT", "/node/$type-$id", $auth);
        warn Dumper($d);
        return 1 if(defined $d->{"D"});
        return 0;
    }
}

sub delete_object {
}
sub get_metadata {
}
sub set_metadata {
}
sub remove_metadata {
}
sub find_objects {
}

sub _buildUA {
    my ($self) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->timeout($ModelSEED::Database::Shock::TIMEOUT);
    return $ua;
}

sub _buildJSON {
    my ($self) = @_;
    return JSON->new->utf(8);
}

sub _makeRequest {
    my ($self, $type, $resource, $payload, $auth) = @_;
    my $uri = uri_join("http", $self->host.":".$self->port, $resource);
    my $req = HTTP::Request->new( $type => $uri );
    $req->content($payload);
    warn Dumper $req;
    # replace basic auth with better methods
    $auth->wrap_http_request($req);
    my $res = $self->ua->request($req);
    warn Dumper $res;
    return undef if( $res->code =~ /5\d\d/ );
    return undef if( $res->code =~ /4\d\d/ );
    return $self->json->decode($res->content);
}

1;
