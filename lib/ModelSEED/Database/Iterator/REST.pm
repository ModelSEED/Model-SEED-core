########################################################################
# ModelSEED::Database::Iterator::REST - Iterator wrapper 
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-21
########################################################################
=pod

=head1 ModelSEED::Database::Iterator::REST

REST implementation of Iterator

=head2 Description

This follows the same interface as L<ModelSEED::Database::Iterator>.

=head2 Initialization

This accepts a reference to a perl structure that is the return
value from a collection resource. That return value should look something
like this:

    {
        limit: 30,
        offset        : 10,
        resultSetSize : 40321,
        results       : [// ... results ...],
        next_url : "http://model-api.theseed.org/biochemistry?limit=30&offset=40",
    }

Or simply the starting uri:

    {
        reference : "http://model-api.theseed.org/biochemistry"
    }

=cut
package ModelSEED::Database::Iterator::REST;
use Moose;
use Moose::Util::TypeConstraints;
use LWP::UserAgent;

with 'ModelSEED::Database::Iterator';

subtype 'ModelSEED::URI', as 'URI';
coerce 'ModelSEED::URI', from 'String', via { URI->new($_); };

has limit  => (is => 'rw', isa => 'Int');
has offset => (is => 'rw', isa => 'Int');
has count => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    builder => '_getCount'
);
has next_url => (
    is      => 'bare',
    isa     => 'ModelSEED::URI',
    lazy    => 1,
    builder => '_getNextFromBase'
);

has reference => (is => 'rw', isa => 'ModelSEED::URI');

has _lastResponse => (
    is      => 'rw',
    isa     => 'HTTP::Response',
    lazy    => 1,
    builder => '_getLastResponse'
);


has _set => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_initResults'
);
has _i => (is => 'rw', isa => 'Int', lazy => 1, builder => '_getI');
has _ua => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    builder => '_buildUA'
);

around 'BUILDARGS' => sub {
    my $orig = shift @_;
    my $self = shift @_;
    my $args = shift @_;
    if(defined($args->{next})) {
        $args->{next_url} = $args->{next};
        delete $args->{next};
    }
    if(defined($args->{results})) {
        $args->{_set} = $args->{results};
        delete $args->{results};
    }
};

sub next {
    my ($self) = @_;
    my ($i, $set) = ($self->_i, $self->_set);
    if($i >= @$set) {
        $set = $self->_pageInNextSet();
    }
    return undef unless($i <= @$set);
    my $rtv = $set->[$i];
    $self->_i( $i + 1 );
    return $rtv;
}

sub all {
    my ($self) = @_;
    my @all = ();     
    while( my $next = $self->next ) {
        push(@all, $next);
    }
    return @all;
}

sub count {
    my ($self) = @_;
    return $self->resultSetSize;
}

sub _getI {
    return $_[0]->offset;
}

sub _initResults {
    my ($self) = @_;
    return [] unless(defined($self->reference));
    my $content = $self->_pageIn($self->reference);
    $self->resultSetSize($content->{resultSetSize});
    $self->next_url($content->{next_url});
    return $content->{results};
}

sub _pageIn {
    my ($self, $url) = @_;
    $url = $self->next_url unless(defined($url));
    my $resp = $self->_ua->get($url);
    if($resp =~ /^2/) {
        return [];
    }
    my $content = $self->_json->decode($resp->content);
    return $content;
}

sub _pageInNextSet {
    my ($self) = @_;
    my $content = $self->_pageIn();
    $self->resultSetSize($content->{resultSetSize});
    $self->next_url($content->{next_url});
    return $self->_set($content->{results});
}
sub _buildUA {
    return LWP::UserAgent->new();
}
sub _buildJSON {
    return JSON->new();
}

1;
