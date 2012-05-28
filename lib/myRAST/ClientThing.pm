#!/usr/bin/perl -w
use strict;

#!/usr/bin/perl -w
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

package ClientThing;

    use strict;
    use YAML;
    use ErrorMessage;
    use Carp;
    no warnings qw(once);
    use POSIX;
    use HTTP::Message;

    use constant AGENT_NAME => "myRAST version 36";

=head1 Base Class for Server Helper Objects

=head2 Description

This object is used as the base class for the various server objects. It provides
the functions needed to invoke one of the servers.

This package deliberately uses no internal SEED packages or scripts, only common
PERL modules.

The fields in this object are as follows.

=over 4

=item server_url

The URL used to request data from the sapling server. If C<localhost> is
specified, then the L<SAP> module will be called directly.

=item ua

The user agent for communication with the server.

=item singleton

Indicates whether or not results are to be returned in singleton mode. In
singleton mode, if the return document is a hash reference with only one
entry, the entry value is returned rather than the hash.

=item methodHash

Reference to a hash keyed by the names of the server's permissible methods.

=back

=head2 Creating a Server Client Package

The code to create a server client package is simple. The following program
is the entire Sapling server.

    package SAPserver;
    use strict;
    use base qw(ClientThing);
    
    sub new {
        my ($class, %options) = @_;
        $options{url} = 'http://servers.nmpdr.org/sapling/server.cgi' if ! defined $options{url};
        return $class->SUPER::new('SAP', %options);
    }
    
    1;

Most methods that the server will support are then handled automatically by the
this class's AUTOLOAD.

=head3 File-Based Data Transfer

Most server methods take YAML input and produce YAML output. In some cases,
however, the size of the input or output precludes packaging everything into
strings for passage directly across the network. For this reason, the utility
methods L<_send_file> and L<_receive_file> have been provided. These allow
entire files of data to be sent and received piecemeal. Methods that require
this capability will need to be specified explicitly in the subclass rather than
relying on the AUTOLOAD.

NOTE: This facility was intended to provide flow control for calls to the
B<query> method in the Sapling Server, but it has never actually been
implemented.

=cut

# Number of bytes to transfer in a data chunk.
use constant CHUNKSIZE => 512*1024;

=head2 Main Object Methods

=head3 new

    my $ss = ClientThing->new($type, %options);

Construct a new server object. The I<$type> parameter should be the server type
(e.g. C<SAP> for the Sapling server, C<FFfunctions> for the FIGfams server). The
following options are supported.

=over 4

=item url

URL for the server. This option is required.

=item singleton (optional)

If TRUE, results from methods will be returned in singleton mode. In singleton
mode, if a single result comes back, it will come back as a scalar rather than
as a hash value accessible via an incoming ID.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $type, %options) = @_;
    # Turn off YAML compression, which causes problems with our hash keys.
    $YAML::CompressSeries = 0;
    # Get the options.
    my $url = $options{url};
    my $singleton = $options{singleton} || 0;
    # Create the fields of the object. Note that if we're in localhost mode,
    # the user agent is actually a SAP object.
    my $server_url = $url;
    my $ua;
    if ($server_url ne 'localhost') {
        # Create the user agent.
        require LWP::UserAgent;
        $ua = LWP::UserAgent->new();
	$ua->agent(AGENT_NAME . " ($^O $^V)");
        # Set the timeout to 20 minutes.
        $ua->timeout(20 * 60);
    } else {
        # Get access to the server package.
        require "$type.pm";
        # Create a service object.
        $ua = eval("$type->new(\$options{sapDB})");
        if ($@) {
            die "Error creating $type object: $@";
        }
    }
    my $accept_encoding = [];
    eval {
	my $can_accept = HTTP::Message::decodable();
	@$accept_encoding = ('Accept-Encoding' => $can_accept);
    };

    # Create the server object.
    my $retVal = { 
                    server_url => $server_url,
                    ua => $ua,
                    singleton => $singleton,
		    accept_encoding => $accept_encoding,
                    dbName => undef,
                 };
    # Bless it.
    bless $retVal, $class;
    # Get the list of permitted methods from the server.
    my $methodList = $retVal->_call_method(methods => []);
    # Convert it to a hash and store it in this object.
    $retVal->{methodHash} = { methods => 1, map { $_ => 1 } @$methodList };
    # Return the object.
    return $retVal;
}

=head3 AUTOLOAD

    my $result = $server->method(%args);

Call a function on the server. Any method call on this object (other than
the constructor) is translated into a request against the server. This
enables us to add new server functions without requiring an update to this
object or its parent. The parameters are usually specified as a hash, and the
result is a scalar or object reference. In some cases the parameters are a list.
To deistinguish between the two cases, all hash keys must begin with hyphens.

If an error occurs, we will throw an exception.

=cut

# This variable will contain the method name.
our $AUTOLOAD;

sub AUTOLOAD {
    # Get the parameters. We do some fancy dancing to allow the user to pass
    # in a hash, a list, a list reference, or a hash reference.
    my $self = shift @_;
    my $args = $_[0];
    if (defined $args) {
        if (scalar @_ gt 1) {
            # Here we have multiple arguments. We check the first one for a
            # leading hyphen.
            if ($args =~ /^-/) {
                # This means we have hash-form parameters.
                my %args = @_;
                $args = \%args;
            } else {
                # This means we have list-form parameters.
                my @args = @_;
                $args = \@args;
            }
        } else {
            # Here we have a single argument. If it's a scalar, we convert it
            # to a singleton list.
            if (! ref $args) {
                $args = [$args];
            }
        }
    }
    # Declare the return variable.
    my $retVal;
    # Get the method name.
    my $function = $AUTOLOAD;
    # Strip off the stuff before the method name.
    $function =~ s/.+:://;
    # Validate the method name.
    if (! $self->{methodHash}{$function}) {
        die "Method \"$function\" not supported.";
    } else {
        # Call the method.
        $retVal = $self->_call_method($function, $args);
        # We have our result. Adjust for singleton mode.
        if ($self->{singleton} && ref $retVal eq 'HASH' && scalar(keys %$retVal) <= 1) {
            # Here we're in singleton mode and we got a single result,
            # so we dereference a bit to make it easier for the user
            # to access it.
            ($retVal) = values %$retVal;
        }
    }
    # Return the result.
    return $retVal;
}

=head3 DESTROY

    $ss->DESTROY();

This method has no function. It's purpose is to keep the destructor from
being caught by the autoload processing.

=cut

sub DESTROY { }

=head3 ChangeDB

    $server->ChangeDB($newDbName);

Specify the new database for future requests against this object.

=over 4

=item newDbName

The name of the new database.

=back

=cut

sub ChangeDB {
    # Get the parameters.
    my ($self, $newDbName) = @_;
    # Store the new database name.
    $self->{dbName} = $newDbName;
}

=head2 Utility Methods

=head3 ComputeURL

    my $url = ClientThing::ComputeURL($url, $cgi, $name);

Compute the URL to use for connecting to this client's server. The default is to
connect to the annotator SEED script, but the client can request direct calls
(localhost), a specific URL, the P-SEED, or a specific SEED sandbox.

If a URL is specified, it is returned without preamble.

If no URL is specified, then the C<SAS_SERVER> environment variable is examined for
the following values.

=over 4

=item localhost

Use direct calls to the server without going through HTTP (only works for the
Sapling and FBAMODEL servers).

=item SEED (default)

Use the main servers for the Annotator SEED data.

=item PSEED

Use the alternate servers for the PSEED data.

=item (other)

In this case, the value will be assumed to be the URL of a SEED sandbox, and the
appropriate script in that sandbox will be used.

=back

The parameters are as follows:

=over 4

=item url (optional)

URL to use, if specified.

=item cgi

Name of the CGI script to use if a SEED sandbox is requested (e.g. C<sap_server.cgi>,
C<anno_server.cgi>).

=item name

Name of the pseudo-directory to use if a server is requested (e.g. C<sapling>, C<anno>).

=item RETURN

Returns the URL to pass to the server interface object constructor.

=back

=cut

sub ComputeURL {
    # Get the parameters.
    my ($url, $cgi, $name) = @_;
    # Do we have an explicit URL?
    my $retVal = $url;
    if (! $retVal) {
        # No. Check the environment variable.
        my $envParm = $ENV{SAS_SERVER} || 'PUBSEED';
        if ($envParm eq 'SEED') {
            $retVal = "http://servers.nmpdr.org/$name/server.cgi";
        } elsif ($envParm eq 'PSEED') {
            $retVal = "http://servers.nmpdr.org/pseed/$name/server.cgi";
        } elsif ($envParm eq 'PUBSEED') {
            $retVal = "http://pubseed.theseed.org/$name/server.cgi";
        } elsif ($envParm eq 'localhost') {
            $retVal = 'localhost';
        } else {
            # Here we have a SEED sandbox. Check for the trailing slash.
            $retVal = $envParm;
            unless ($retVal =~ m#/$#) {
                $retVal .= "/";
            }
            # Check for the HTTP prefix.
            unless ($retVal =~ m#^http://#i) {
                $retVal = "http://$retVal";
            }
            # Append the script name.
            $retVal .= $cgi;
        }
    }
    # Return the computed URL.
    return $retVal;
}

=head3 FixOptions

    my %options = ClientThing::FixOptions(@options);

This method allows more options for the specification of parameters to a server's
client module. First, the input can be specified as a hash or a hash reference,
and the keys can optionally have hyphens prefixed. (So, for example, the key
C<-url> would be converted to C<url>.)

=cut

sub FixOptions {
    # Get the parameters.
    my (@options) = @_;
    # Create the return hash.
    my %retVal;
    if (@options == 1 && ref $options[0] eq 'HASH') {
        my $optionHash = $options[0];
        # Here the user specified a hash reference. Transfer its to
        # the return hash, removing hyphens from key names.
        for my $key (keys %$optionHash) {
            if ($key =~ /^-(.+)/) {
                $retVal{$1} = $optionHash->{$key};
            } else {
                $retVal{$key} = $optionHash->{$key};
            }
        }
    } else {
        # Here the user specified a regular hash. We need to convert it
        # from a list.
        for (my $i = 0; $i < @options; $i += 2) {
            # Get the key of the current pair.
            my $key = $options[$i];
            # Strip off the hyphen (if any).
            if ($key =~ /^-(.+)/) {
                $key = $1;
            }
            # Store the value with the key in the output hash.
            $retVal{$key} = $options[$i + 1];
        }
    }
    # Return the computed hash.
    return %retVal;
}

=head3 _call_method

    my $result = $server->_call_method($method, $args);

Call the specified method on the server with the specified arguments and
return the result. The arguments must already be packaged as a hash or
list reference. This method is the heart of the AUTOLOAD method, and is
provided as a utility for specialized methods that can't use the AUTOLOAD
facility.

=over 4

=item method

Name of the server function being invoked.

=item args

Argument object to pass to the function.

=item RETURN

Returns a hash or list reference with the function results.

=back

=cut

sub _call_method {
    # Get the parameters.
    my ($self, $method, $args) = @_;
    # Declare the return variable.
    my $retVal;
    # Get our user agent.
    my $ua = $self->{ua};
    # Determine the type.
    if (ref $ua eq 'LWP::UserAgent') {
        # Here we're going to a server. Compute the argument document.
        my $argString = YAML::Dump($args);
        # Request the function from the server.
        my $content = $self->_send_request(function => $method, args => $argString,
                                           source => __PACKAGE__,
                                           dbName => $self->{dbName});
        $retVal = YAML::Load($content);
    } else {
        # Here we're calling a local method.
        $retVal = eval("\$ua->$method(\$args)");
        # Check for an error.
        if ($@) {
            die "Package error: $@";
        }
    }
    # Return the result.
    return $retVal;
}

=head3 _send_file

    my $name = $server->_send_file($ih);

Send a file of data to the server and return its name.

=over 4

=item ih

Open input file handle or the name of the input file.

=item RETURN

Returns the name of the file created on the server. This is not the full name
of the file; rather, it is enough information for the server to find the file
again when it needs it.

=back

=cut

sub _send_file {
    # Get the parameters.
    my ($self, $ih) = @_;
    # Declare the return variable.
    my $retVal;
    # Get the user agent.
    my $ua = $self->{ua};
    # Find out if we have a handle or a file name. When we're done, we'll have an
    # open handle to the file in $ih_real.
    my $ih_real;
    if (ref $ih eq 'GLOB') {
        $ih_real = $ih;
    } else {
        open $ih_real, "<$ih" || die "File error: $!";
    }
    # Are we in localhost mode?
    if (ref $ua eq 'LWP::UserAgent') {
        # Tell the server to create the file and get the file name back.
        $retVal = $self->_send_request(file => 'create');
        # Loop through the input, reading and sending chunks of data.
        my ($chunk, $rc);
        while (! eof $ih) {
            # Get a chunk of data.
            my $rc = read $ih, $chunk, CHUNKSIZE;
            # Check for errors.
            if (! defined $rc) {
                die "File error: $!";
            } elsif ($rc > 0) {
                # Here we have data to send.
                $self->_send_request(file => 'write', name => $retVal, data => $chunk);
            }
        }
    } else {
        # Here we're in local mode. We need a copy of the file in the FIG temporary
        # directory.
        require File::Temp;
        require FIG_Config;
        my ($oh, $fileName) = File::Temp::tempfile('tempSERVERsendFileXXXXX',
                                                   suffix => 'txt', UNLINK => 1,
                                                   DIR => $FIG_Config::temp);
        # Copy the input file to the output.
        while (! eof $ih) {
            my $line = <$ih_real>;
            print $oh $line;
        }
        close $oh;
        # Return the file name.
        $retVal = $fileName;
    }
    # Return the result.
    return $retVal;
}

=head3 _receive_file

    $server->_receive_file($oh, $name);

Retrieve the named file of data from the server.

=over 4

=item oh

Open file handle to which the data is to be written, or the name of the file to
contain the data.

=item name

Name of the data file in the FIG temporary directory on the server.

=back

=cut

sub _receive_file {
    # Get the parameters.
    my ($self, $oh, $name) = @_;
    # Get the user agent.
    my $ua = $self->{ua};
    # Find out if we have a handle or a file name. When we're done, we'll have
    # an open handle to the file in $oh_real.
    my $oh_real;
    if (ref $oh eq 'GLOB') {
        $oh_real = $oh;
    } else {
        open $oh_real, ">$oh" || die "File error: $!";
    }
    # Are we in localhost mode?
    if (ref $ua eq 'LWP::UserAgent') {
        # No, we must get this file from the server. Tell the server to get us
        # the length of the file.
        my $length = $self->_send_request(file => 'open', name => $name);
        # Loop through the file, reading chunks.
        my $location = 0;
        while ($location < $length) {
            my $chunk = $self->_send_request(file => 'read', name => $name,
                                             location => $location, size => CHUNKSIZE);
            print $oh_real $chunk;
            $location += length $chunk;
        }
    } else {
        # Open the named file for input.
        require FIG_Config;
        open my $ih, "<$FIG_Config::temp/$name";
        # Copy it to the output.
        while (! eof $ih) {
            my $line = <$ih>;
            print $oh_real $line;
        }
    }
    # If we opened the output file ourselves, close it.
    if (ref $oh ne 'GLOB') {
        close $oh_real;
    }
}


=head3 _send_request

    my $result = $server->_send_request(%parms);

Send a request to the server. This method must not be called in localhost
mode. If an error occurs, this method will die; otherwise, the content of
the response will be passed back as the result.

=over 4

=item parms

Hash of CGI parameters to send to the server.

=item RETURN

Returns the string returned by the server in response to the request.

=back

=cut

sub _send_request {
    # Get the parameters.
    my ($self, %parms) = @_;
    # Get the user agent.
    my $ua = $self->{ua};
    # Request the function from the server. Note that the hash is actually passed
    # as a list reference.
    #
    # retries is the set of retry wait times in seconds we should use. when
    # we run out the call will fail.
    #

    my @retries = (1, 2, 5, 10, 20, 60, 60, 60, 60, 60, 60);
    my %codes_to_retry =  map { $_ => 1 } qw(110 408 502 503 504 200 500) ;
    my $response;

    while (1) {
        $response = $ua->post($self->{server_url}, [ %parms ],
			      @{$self->{accept_encoding}},
			     );
        if ($response->is_success) {
            my $retVal = $response->decoded_content;
            return $retVal;
        }

        #
        # If this is not one of the error codes we retry for, or if we
        # are out of retries, fail immediately
        #
        my $code = $response->code;
        if (!$codes_to_retry{$code} || @retries == 0) {
            if ($ENV{SAS_DEBUG}) {
                my $content = $response->content;
                if (! $content) {
                    $content = "Unknown error from server.";
                }
                confess $content;
            } else {
                confess $response->status_line;
            }
        }
        
        #
        # otherwise, sleep & loop.
        #
        my $retry_time = shift(@retries);
        print STDERR strftime("%F %T", localtime), ": Request failed with code=$code, sleeping $retry_time and retrying\n";
        sleep($retry_time);

    }

    #
    # Should never get here.
    #
}


1;
