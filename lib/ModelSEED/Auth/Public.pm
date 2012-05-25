########################################################################
# ModelSEED::Auth::Public - Class for not-logged in state
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

=head1 ModelSEED::Auth::Public

No athorization version.

=head1 Methods

=head2 new

    $auth = ModelSEED::Auth::Public->new();

No arguments are required.

=cut
package ModelSEED::Auth::Public;
use Moose;
use common::sense;
use namespace::autoclean;
use Class::Autouse qw(
    HTTP::Request
);

sub wrap_http_request {
    my ($self, $req) = @_;
    die "Not an HTTP::Request" unless($req->isa("HTTP::Request"));
    return 1;
}
sub username { return 'PUBLIC'; }

with 'ModelSEED::Auth';
__PACKAGE__->meta->make_immutable;
1;

