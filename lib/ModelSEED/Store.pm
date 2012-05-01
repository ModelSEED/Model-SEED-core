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

=head1 NAME

ModelSEED::Store - Authenticated storage interface layer

=head1 METHODS

=head2 new

    my $Store = ModelSEED::Store->new(\%);

This initializes a Storage interface object. This accepts a hash
reference to configuration details. In addition to authentication,
which is required and will be covered in a moment, this currently
accepts one parameter:

=over

=item C<private>

A reference to a C<ModelSEED::Store::Private> object. This is the
base storage interface that the Store will use. If this is not
provided, it will be initialized based on the contents of the
C<ModelSEED::Configuration> package.

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
to use the C<ModelSEED::ModelSEEDClients::MSSeedSupportClient>
package to retrieve authentication information from the central
servers.

=back

=head2 Other Functions

This package has the same set of functions as C<ModelSEED::Store::Private>
but these functions do not accept a "user" as the first argument.
All other arguments are "shifted up by one". For example, in the
private interface, we have this function:

    my $data = $StorePrivate->get_data("alice", "model", "alice/myModel");

This is equivalent to the following function in the C<ModelSEED::Store>
interface, provided that the user C<alice> authenticated during
initialization:

    my $data = $Store->get_data("model", "alice/myModel");

Therefore, you should consult the C<ModelSEED::Store::Private>
documentation for further method details.

=cut
package ModelSEED::Store;
use Moose;
use ModelSEED::Store::Private;
use ModelSEED::ModelSEEDClients::MSSeedSupportClient;
use ModelSEED::MS::User;
use Data::Dumper;

has username => ( is => 'rw', isa => 'Str', required => 1 );
has user => ( is => 'rw', isa => 'ModelSEED::MS::User');
has private => ( is => 'ro', isa => 'ModelSEED::Store::Private', required => 1);

around BUILDARGS => sub {
    my ($orig, $class, $args) = @_;
    my $authorized = 0; 
    my $private = $args->{private};
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
                $private->create_user($user->login, $user->serializeToDB);
            }
        }
        if($user->check_password($args->{password})) {
            $authorized = 1;
        }
        $args->{user} = $user;
    }
    die "Unauthorized" unless($authorized);
    return $class->$orig($args);
};

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
