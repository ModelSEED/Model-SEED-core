########################################################################
# ModelSEED::MS::User - This is the moose object corresponding to the User object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::User;
package ModelSEED::MS::User;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::User';

sub set_password {
    my ($self, $password) = @_;
    my $new_password = encrypt($password);
    $self->password($new_password);
    return 1;
}

sub check_password {
    my ($self, $password) = @_;
    if (crypt($password, $self->password) eq $self->password) {
        return 1;
    } else {
        return 0;
    }
}

sub encrypt {
    my ($password) = @_;
    my $seed = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    return crypt($password, $seed);
}

__PACKAGE__->meta->make_immutable;
1;
