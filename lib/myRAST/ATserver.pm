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

package ATserver;

use strict;
use base qw(ClientThing);

use Data::Dumper;

sub new {
    my ($class, @options) = @_;

    my %options = ClientThing::FixOptions(@options);

    $options{url} ||= 'http://servers.theseed.org/figdisk/FIG/AT_server.cgi';
    # $options{url} ||= "http://bioseed.mcs.anl.gov/~fangfang/FIG/AT_server.cgi";
    # $options{url} = ClientThing::ComputeURL($options{url}, 'AT_server.cgi', 'AT');
    # $options{url} = "localhost";

    return $class->SUPER::new(AT => %options);
}


1;
