#
# This is a SAS Component
#

package FBAMODELClient;

use strict;
use base qw(ClientThing);

sub new {
    my($class, @options) = @_;
    my %options = ClientThing::FixOptions(@options);
	if (!defined($options{url})) {
		$options{url} = "http://bioseed.mcs.anl.gov/~chenry/FIG/CGI/FBAMODEL_server.cgi";
	}
    return $class->SUPER::new("ModelSEED::ServerBackends::FBAMODEL" => %options);
}

1;
