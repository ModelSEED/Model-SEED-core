########################################################################
# ModelSEED::MS::Biochemistry - This moose object stores data on user environment
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-18
########################################################################
use ModelSEED::FileDB;
package ModelSEED::Config;
use Moose;
use Config::Tiny;
use namespace::autoclean;

with ( 
    'ModelSEED::Config::Store' => { type => 'file', class => 'ModelSEED::FileDB' }
);

has filename => (
    is  => 'rw',
    isa => 'Str',
    builder => '_buildFilename',
    lazy => 1,
);

has Config => (
    is => 'rw',
    isa => 'Config::Tiny',
    builder => '_buildConfig',
    lazy => 1,
    init_arg => undef,
);

sub _buildConfig {
    my ($self) = @_;
    if( -f $self->filename ) {
        my $config = Config::Tiny->read($self->filename);
        return $config;
    } else {
        return Config::Tiny->new;
    }
}

sub _buildFilename {
    return $ENV{HOME} . "/.modelseed";
}

sub save {
    my ($self) = @_;
    $self->Config->write($self->filename);
}

sub getSection {
    my ($self, $section) = @_;
    $section ||= '_';
    my $rtv = undef;
    foreach my $key (keys %{$self->Config->{$section}}) {
        $rtv = {} if(!defined($rtv));
        $rtv->{$key} = $self->get($section, $key); 
    }
    return $rtv;
}

sub get {
    my ($self, $section, $key) = @_;
    die unless (defined($section) && defined($key));
    return $self->Config->{$section}->{$key};
}

sub setSection {
    my ($self, $section, $value) = @_;
    die unless (defined($section));
    if(!defined($value)) {
        delete $self->Config->{$section};
    } else {
        foreach my $key (keys %$value) {
            $self->set($section, $key, $value->{$key});
        }
    }
    return $self->getSection($section);
}

sub set {
    my ($self, $section, $key, $value) = @_;
    die unless(defined($section) && defined($key));
    if(!defined($value)) {
        delete $self->Config->{$section}->{$key};
    } else {
        $self->Config->{$section}->{$key} = $value;
    }
    return $self->get($section, $key);
}

__PACKAGE__->meta->make_immutable;
1;
