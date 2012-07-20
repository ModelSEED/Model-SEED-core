package MSAccountManagementClient;

use base qw(ClientThing);

sub new {
    my($class, @options) = @_;
    my %options = ClientThing::FixOptions(@options);
    if (!defined($options{url})) {
	$options{url} = "http://pubseed.theseed.org/model-prod/MSAccountManagement.cgi";
    }
    return $class->SUPER::new("MSAccountManagement" => %options);
}

1;
