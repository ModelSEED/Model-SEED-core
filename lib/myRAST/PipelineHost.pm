
package PipelineHost;

=head1 DESCRIPTION

A pipeline host is a role implemented by objects that hold
pipeline stages. It provides the framework for status callbacks
from the pipeline stages.

=cut

use Moose::Role;

has 'notify_port' => (is => 'rw',
		      isa => 'Num',
		      default => 0);

1;

