########################################################################
# ModelSEED::Auth::Basic - Basic Auth ( username + password )
# Authorization
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-16
########################################################################
=pod

=head1 ModelSEED::Auth::Basic

Do basic authentication ( username + password )

=head1 Methods

=head2 new

    $auth = ModelSEED::Auth::Basic->new({
        username => $username,
        password => $password
    });

C<Username> and C<Password> are required.

=cut
package ModelSEED::Auth::Basic;
use Moose;
use common::sense;
use namespace::autoclean;
use MIME::Base64;
use Class::Autouse qw(
    HTTP::Request
);

has username => ( is => 'ro', isa => 'Str', required => 1);
has password => ( is => 'ro', isa => 'Str', required => 1);

sub wrap_http_request {
    my ($self, $req) = @_;
    die "Not an HTTP::Request" unless($req->isa("HTTP::Request"));
    my ($username, $password) = ($self->username, $self->password);
    my $base64 = encode_base64("$username:$password");
    $req->header( "Authorization" => "Basic: $base64" ); 
    return 1;
}

with 'ModelSEED::Auth';
__PACKAGE__->meta->make_immutable;
1;
