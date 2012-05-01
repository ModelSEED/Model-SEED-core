########################################################################
# ModelSEED::Configuration - This moose object stores data on user env
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: 
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-03-18
########################################################################
=pod

=head1 NAME

ModelSEED::Configuration - Simple interface to store configuration info

=head1 DESCRIPTION

This module provides a simple interface to get and store configuration
information for the ModelSEED environment. This information is backed
by a JSON file whose location is defined at object construction.

=head1 METHODS

=head2 new

This initializes a configuration object. The method accepts an optional
filename inside a hashref:

    my $Config = ModelSEED::Configuration->new({filename => 'path/to/file.json'});

If no filename is supplied, the enviornment variable C<MODELSEED_CONFIG>
is checked. If this variable is defined and is a valid path, it is
used.  Otherwise the default is to store configuration at C<.modelseed>
in the current user's C<$HOME> directory.

=head2 config

Returns a hashref of configuration information. From the perspective
of ModelSEED::Configuration, this hashref is unstructured, and may
contain keys pointing to strings, arrays or other hashrefs.

    my $item = $Config->config->{key};

=head2 save

Saves the data to the JSON file. This must be done manually whenever
the configuration state is changed.

    $Config->save();

=cut

package ModelSEED::Configuration;
use Moose;
use namespace::autoclean;
use JSON;
use File::Path qw(mkpath);
use File::Basename qw(dirname);

has filename => (
    is      => 'rw',
    isa     => 'Str',
    builder => '_buildFilename',
    lazy    => 1,
);

has config => (
    is       => 'rw',
    isa      => 'HashRef',
    builder  => '_buildConfig',
    lazy     => 1,
    init_arg => undef,
);

has JSON => (
    is       => 'ro',
    isa      => 'JSON',
    builder  => '_buildJSON',
    lazy     => 1,
    init_arg => undef
);

sub _buildConfig {
    my ($self) = @_;
    if (-f $self->filename) {
        local $/;
        open(my $fh, "<", $self->filename) || die "$!";
        my $text = <$fh>;
        close($fh);
        return $self->JSON->decode($text);
    } else {
        return {};
    }
}

sub _buildJSON {
    return JSON->new->utf8(1)->pretty(1);
}

sub _buildFilename {
    my $filename = $ENV{MODELSEED_CONF};
    $filename  ||= $ENV{HOME} . "/.modelseed";
    mkpath dirname($filename) unless(-d dirname($filename));
    return $filename;
}

sub save {
    my ($self) = @_;
    open(my $fh, ">", $self->filename);
    print $fh $self->JSON->encode($self->config);
    close($fh);
}

__PACKAGE__->meta->make_immutable;
1;
