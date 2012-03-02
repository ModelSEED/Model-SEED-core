package ModelSEED::MS::Model;

use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::utilities;
use ModelSEED::MS::Biochemistry;
use Carp qw(cluck);
use namespace::autoclean;
use DateTime;
use Data::UUID;

has om          => (is => 'rw', isa => 'ModelSEED::CoreApi');
has uuid        => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has modDate     => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has locked      => (is => 'rw', isa => 'Int', default => 0);
has public      => (is => 'rw', isa => 'Int', default => 1);
has id          => (is => 'rw', isa => 'Str', default => '');
has name        => (is => 'rw', isa => 'Str', default => '');
has version     => (is => 'rw', isa => 'Int', default => 0);
has type        => (is => 'rw', isa => 'Str', default => '');
has status      => (is => 'rw', isa => 'Str', default => '');
has reactions   => (is => 'rw', isa => 'Int', default => 0);
has compounds   => (is => 'rw', isa => 'Int', default => 0);
has annotations => (is => 'rw', isa => 'Int', default => 0);
has growth      => (is => 'rw', isa => 'Num', default => 0);
has current     => (is => 'rw', isa => 'Int', default => 0);

has biochemistry =>
    (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', default => undef);

#has mapping

#has annotation

# Constants
has dbAttributes =>
    (is => 'ro', isa => 'ArrayRef[Str]', builder => '_buildDbAttributes');
has indices =>
    (is => 'rw', isa => 'HashRef', lazy 1, builder => '_buildindices');
has _type => (is => 'ro', isa => 'Str', default => 'Model');

#Internally maintained variables
has changed => (is => 'rw', isa => 'Bool', default => 0);

sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    return $params;
}

sub BUILD {
    my ($self, $params) = @_;
    my $rels = $params->{relationships};
    if(defined($rels)) {
		my $subObjects = {
		    biochemistry => "ModelSEED::MS::Biochemistry",
		    annotation => "ModelSEED::MS::Annotation",
		    mapping => "ModelSEED::MS::Mapping"
		};
        my $order = [qw(biochemistry)]; # only get biochemistry for now
        foreach my $name (@$order) {
            my $values = $rels->{$name};
            $params->{$name} = [];
            my $class = $subObjects->{$name};
            foreach my $data (@$values) {
		# do we need to pass model down?
		# $data->{biochemistry} = $self;
                push(@{$self->{$name}}, $class->new($data));
            }
		}
        delete $params->{relationships}
    }
}

