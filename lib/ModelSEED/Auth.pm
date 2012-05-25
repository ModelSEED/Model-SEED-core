########################################################################
# ModelSEED::Auth - Abstract role / interface for authentication
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-16
########################################################################
=pod

=head1 ModelSEED::Auth

Abstract role for authentication implementations.

=head1 Abstract

There are multiple different ways one could authenticate against
an API, a data store, etc. For example, there is the "basic auth"
of a username + password pair. Then there is an OAuth token and
secret. The point of this interface is to abstract these implementations.

=head1 Methods

=head2 new

Each implementation has it's own version of initialization.

=head2 wrap_http_request 

    $bool = $auth->wrap_http_request($request)

Given a HTTP::Request object, wrap that object in authentication
info and return success (1). If there are problems, this returns
false (0). The request object is modified by this call.

=head2 username

    $string = $auth->username();

Return a username.

=cut
package ModelSEED::Auth;
use Moose::Role;
use common::sense;
use namespace::autoclean;

requires 'wrap_http_request';

requires 'username';

1;
