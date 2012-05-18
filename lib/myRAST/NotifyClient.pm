#
# This is a little class that sends notifications to a
# NotificationServer. Used for updating the GUI when
# status changes on a helper application.
#

package NotifyClient;

use YAML::Any;
use IO::Socket::INET;

use Moose;

has 'port' => (is => 'ro',
	       isa => 'Num');

has 'host' => (is => 'ro',
	       isa => 'Str',
	       default => 'localhost');

has 'handle' => (is => 'ro',
		 isa => 'Str');

has 'socket' => (isa => 'Maybe[IO::Socket::INET]',
		 is => 'ro',
		 lazy => 1,
		 builder => '_connect');

sub _connect
{
    my($self) = @_;
    
#    print "Notify connect to $self->{host} $self->{port}\n";

    if ($self->port <= 0)
    {
	return undef;
    }

    my $sock = IO::Socket::INET->new(PeerHost => $self->host,
				     PeerPort => $self->port,
				     Proto => 'tcp');
    return $sock;
}

sub status
{
    my($self, $msg) = @_;
    $self->send([status => $msg]);
}

sub progress
{
    my($self, $val, $range) = @_;
    $self->send([progress => [$val, $range]]);
}

sub send
{
    my($self, @items) = @_;

    return if !defined($self->socket);

    my $txt = Dump([$self->handle => \@items]);
    my $len = length($txt);
    $self->socket->print(pack("N", $len) . $txt);
}

1;
