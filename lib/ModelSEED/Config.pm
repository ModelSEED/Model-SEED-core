########################################################################
# ModelSEED::MS::Biochemistry - This moose object stores data on user environment
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-18
########################################################################
package ModelSEED::Config;
use Moose;
use JSON;
use namespace::autoclean;

has filename => (
    is  => 'rw',
    isa => 'Str',
    builder => '_buildFilename',
    lazy => 1,
);

has config => (
    is => 'rw',
    isa => 'HashRef',
    builder => '_buildConfig',
    lazy => 1,
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
    if( -f $self->filename ) {
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
    return $ENV{HOME} . "/.modelseed";
}

sub save {
    my ($self) = @_;
    open(my $fh, ">", $self->filename);
    print $fh $self->JSON->encode($self->config);
    close($fh);
}

__PACKAGE__->meta->make_immutable;
1;
