package ModelSEED::ModelDB::USERS;

use strict;
use warnings;

1;

# this class is a stub, this file will not be automatically regenerated
# all work in this module will be saved

=pod

=item * B<set_password> (I<password>, I<application>)

This method sets the password for a user to (I<password>). The
I<application> parameter is optional. If present, a mail will be
sent to the user with his password enclosed.

=cut

sub set_password {
  my ($self, $password) = @_;
  my $new_password = encrypt($password);
  $self->password($new_password);
  return 1;
}

=pod

=item * B<check_password> (I<password>)

This method checks whether the passed password (I<password>) matches that of the user. 

=cut

sub check_password {
  my ($self, $password) = @_;
  if (crypt($password, $self->password) eq $self->password) {
    return 1;
  } else {
    return 0;
  }
}