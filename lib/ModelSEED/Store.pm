########################################################################
# ModelSEED::Store - Authenticated storage interface layer
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-01
########################################################################
=pod

=head1 ModelSEED::Store 

Authenticated storage interface layer

=head1 METHODS

=head2 new

    my $Store = ModelSEED::Store->new(\%);

This initializes a Storage interface object. This accepts a hash
reference to configuration details. In addition to authentication,
which is required and will be covered in a moment, this currently
accepts one parameter:

=over

=item private

A reference to a L<ModelSEED::Store::Private> object. This is the
base storage interface that the Store will use. If this is not
provided, it will be initialized based on the contents of the
L<ModelSEED::Configuration> package.

=back

=head3 Authentication

The C<new> method requires authentication information. Without this,
or if authentication fails, the class will raise an exception
C<"Unauthorized">. Currently the class accepts one type of
authentication:

=over

=item Basic

Basic Authentication - Requires "username" and "password" fields.
This will attempt to authenticate against the data in the Store::Private
dataset under the type "user". If no user is found, it will attempt
to use the L<ModelSEED::ModelSEEDClients::MSSeedSupportClient>
package to retrieve authentication information from the central
servers.

=back

=head2 Other Functions

This package has the same set of functions as C<ModelSEED::Store::Private>
but these functions do not accept a "user" as the first argument.
All other arguments are "shifted up by one". For example, in the
private interface, we have this function:

    my $data = $StorePrivate->get_data("alice", "model", "alice/myModel");

This is equivalent to the following function in the L<ModelSEED::Store>
interface, provided that the user C<alice> authenticated during
initialization:

    my $data = $Store->get_data("model", "alice/myModel");

Therefore, you should consult the L<ModelSEED::Store::Private>
documentation for further method details.

=head2 Helper Functions

Finally this class has a few helper functions that assist in
object creation. Currently there is only one function:

=head3 create

    my $object = $Store->create("Biochemistry, { name => "Foo" });

This creates a L<ModelSEED::MS::Biochemistry> object and returns
it.  It does not save the object, however, it does initialize the
object with the "parent" pointing back at the C<$Store> instance.
This instance will be used if C<$object->save()> is called without
another store object. It will also be used if the L<ModelSEED::MS>
object needs additional data.

=cut
package ModelSEED::Store;
use Moose;
use ModelSEED::Store::Private;
use ModelSEED::ModelSEEDClients::MSSeedSupportClient;
use ModelSEED::MS::User;
use Try::Tiny;
use Module::Load;

has username => ( is => 'rw', isa => 'Str', required => 1 );
has user => ( is => 'rw', isa => 'ModelSEED::MS::User');
has private => ( is => 'ro', isa => 'ModelSEED::Store::Private');

around BUILDARGS => sub {
    my ($orig, $class, $args) = @_;
    my $authorized = 0;
    my $private = $args->{private};
    unless (defined($private)) {
        $args->{private} = $private = ModelSEED::Store::Private->new();
    }
    # Handle Authentication methods
    if(defined($args->{username}) && defined($args->{password})) {
        my $user = $private->get_user($args->{username});
        unless(defined($user)) {
            # Try to get the user from SEED - LEGACY
            # and create the object
            my $svr = MSSeedSupportClient->new();
            my $info = $svr->get_user_info({
                username => $args->{username},
                password => $args->{password}
            });
            if(defined($info->{username})) {
                $user = ModelSEED::MS::User->new({
                        login => $info->{username},
                        password => $info->{password},
                        firstname => $info->{firstname},
                        lastname => $info->{lastname},
                        email => $info->{email},
                    });
                $private->create_user($user);
            }
        }
        # Check if plaintext password passed
        if($user->check_password($args->{password})) {
            $authorized = 1;
        # Check if crypt + salted password passed
        } elsif($user->password eq $args->{password}) {
            $authorized = 1;
        }
        $args->{user} = $user;
    } else {
        $args->{username} = "PUBLIC";
        $authorized = 1;
    }
    die "Unauthorized" unless($authorized);
    return $class->$orig($args);
};

sub create {
    my ($self, $type, $base_hash) = @_;
    $base_hash = {} unless(defined($base_hash));
    my $className = uc(substr($type,0,1)).substr($type,1);
    $className = "ModelSEED::MS::".$className;
    try {
        load $className;
    } catch {
        die "Unknown class for $type";
    };
    $base_hash->{parent} = $self unless(defined($base_hash->{parent}));
    return $className->new($base_hash);
}

sub AUTOLOAD {
    my $self = shift @_;
    my $call = our $AUTOLOAD;
    return if $AUTOLOAD =~ /::DESTROY$/;
    $call =~ s/.*://;
    return $self->private->$call($self->username, @_);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
