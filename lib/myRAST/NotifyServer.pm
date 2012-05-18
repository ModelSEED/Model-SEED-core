package NotifyServer;
use Moose;
use Data::Dumper;
use YAML::Any;

use Wx qw(:everything :socket);
use Wx::Socket;

use Wx::Event qw(EVT_SOCKET_CONNECTION EVT_SOCKET_INPUT EVT_SOCKET_LOST);

has 'listener' => (isa => 'Wx::SocketServer',
		   is => 'rw');

has 'connection_list' => (isa => 'ArrayRef[Wx::SocketBase]',
			  is => 'ro',
			  default => sub { [] },
			  );

has 'callback_list' => (isa => 'HashRef[CodeRef]',
			is => 'ro',
			default => sub { {} },
			traits => ['Hash'],
			handles => {
			    set_callback => 'set',
			    remove_callback => 'delete',
			    find_callback => 'get',
			},
		       );

has 'socket_to_callback_map' => (isa => 'HashRef',
				 is => 'ro',
				 default => sub { {} },
				 );


has 'window' => (isa => 'Wx::Window',
		is => 'ro');

has 'port' => (isa => 'Num',
	       is => 'rw',
	       default => 0);

sub BUILD
{
    my($self) = @_;

    my $l = Wx::SocketServer->new('0.0.0.0', 0, wxSOCKET_NONE | wxSOCKET_REUSEADDR);
    my($me_host, $me_port) = $l->GetLocal();

    print "Listening on $me_port\n";
    $self->port($me_port);

    EVT_SOCKET_CONNECTION($self->window, $l, sub { $self->on_connect(@_); });
    $self->listener($l);
}

sub on_connect
{
    my($self, $sock, $window, $evt) = @_;
    print "on connect @_\n";
    my $client = $sock->Accept(0);

    $client->SetFlags(wxSOCKET_WAITALL | wxSOCKET_BLOCK);
    my @peer = $client->GetPeer;
    print "Accepted connection from @peer\n";

    EVT_SOCKET_INPUT($self->window, $client, sub { $self->on_input(@_); });
    EVT_SOCKET_LOST($self->window, $client, sub { $self->on_close(@_); });
}

sub on_input
{
    my($self, $sock, $window, $evt) = @_;
    my @loc = $sock->GetLocal();
#    print "Input from socket $sock @loc\n";
    my $buf;
    my $n = $sock->Read($buf, 4);
    my($len) = unpack("N", $buf);

#    print "Reading $len\n";

    $n = $sock->Read($buf, $len);
#    print "Got $n\n";
    my $dat;
    eval {
	$dat = Load($buf);
    };
    if ($dat)
    {
	if (ref($dat) eq 'ARRAY')
	{
	    my $handle = $dat->[0];
	    my $body = $dat->[1];
	    my $cb = $self->find_callback($handle);
	    if (defined($cb))
	    {
		$self->socket_to_callback_map->{$sock} = $handle;
#		print "Processing data for $handle\n";
		&$cb($handle, $body);
	    }
	    else
	    {
#		print "No callback for $handle\n";
		# print Dumper($body);
	    }
	}
    }
}

sub on_close
{
    my($self, $sock, $window, $evt) = @_;

    my $handle = delete $self->socket_to_callback_map->{$sock};

    print "close on socket $sock \n";

    if (defined($handle))
    {
	my $cb = $self->find_callback($handle);
	if (defined($cb))
	{
	    print "Processing close for $handle\n";
	    &$cb($handle, undef);
	}
	else
	{
	    print "No callback for $handle\n";
	}
    }
}

1;
