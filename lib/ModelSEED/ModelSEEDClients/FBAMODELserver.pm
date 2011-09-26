#
# This is a SAS Component
#

package FBAMODELserver;

use strict;
use base qw(ClientThing);

sub new {
    my($class, @options) = @_;
    my %options = ClientThing::FixOptions(@options);
	if (!defined($options{url})) {
		$options{url} = "http://pubseed.theseed.org/model-prod/FBAMODEL_server.cgi";
	}
    return $class->SUPER::new("ModelSEED::FBAMODEL" => %options);
}

1;
