#
# This is a SAS Component
#

package ModelDBserver;

use strict;
use base qw(ClientThing);

sub new {
    my($class, @options) = @_;
    my %options = ClientThing::FixOptions(@options);
	if (!defined($options{url})) {
		$options{url} = ClientThing::ComputeURL($options{url}, 'ModelDB_server.cgi', 'model-prod');
	}
    $options{url} =~ s/\/server\.cgi$/\/ModelDB_server.cgi/; # switch /server.cgi to /FBAMODEL_server.cgi
    return $class->SUPER::new("ModelSEED::ModelSEEDServers::ModelDBServer" => %options);
}

1;
