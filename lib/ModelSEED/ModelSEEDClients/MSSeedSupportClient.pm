#
# This is a SAS Component
#
package MSSeedSupportClient;

use strict;
use base qw(ClientThing);

sub new {
    my($class, @options) = @_;
    my %options = ClientThing::FixOptions(@options);
	if (!defined($options{url})) {
		$options{url} = "http://bioseed.mcs.anl.gov/~devoid/FIG/MSSeedSupport_server.cgi";
	}
    return $class->SUPER::new("MSSeedSupport" => %options);
}

1;
