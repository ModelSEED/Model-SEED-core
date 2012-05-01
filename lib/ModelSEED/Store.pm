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
                $private->create_user("user", $user->login,
                    $user->serializeToDB);
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
