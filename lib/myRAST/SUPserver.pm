#
#	This is a SAS Component.
#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

package SUPserver;

    use strict;
    use base qw(ClientThing);

=head1 Sapling Update Server Helper Object

=head2 Description

This module is used to call the sapling update server, which is a 
server for updating data in the Sapling database. Each Sapling Update
Server function corresponds to a method of this object. In other words,
all L<SUP/Primary Methods> are also methods here.

=cut

=head3 new

    my $ss = SUPserver->new(%options);

Construct a new SUPserver object. The following options are supported.

=over 4

=item url

URL for the sapling update server. This option may be used to redirect requests
to a test version of the server, or to an older server script.

=item singleton

If TRUE, results from methods will be returned in singleton mode. In singleton
mode, if a single result comes back, it will come back as a scalar rather than
as a hash value accessible via an incoming ID.

=item dbName

Name of the database to use, if it is to be different from the default.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, @options) = @_;
    # Fix the option hash.
    my %options = ClientThing::FixOptions(@options);
    # Compute the URL.
    $options{url} = ClientThing::ComputeURL($options{url}, 'sup_server.cgi',
                                            'sapupdate');
    # Construct the subclass.
    return $class->SUPER::new(SUP => %options);
}


1;
