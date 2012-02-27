package ModelSEED::Import::Checker;
use strict;
use warnings;
use Moose;
use JSON::Any;
use File::Slurp;
use Cwd 'abs_path';

with 'MooseX::Log::Log4perl';

# ## Import::Checker
# Check that the import of a biochemistry, model,
# annotation, genome, mapping, etc. ran smoothly.
#
# Supports explicitly defining "expected" errors,
# and what to do when there are "unexpected" errors.

# ## Arguments
# - expectedFailure: Indicate which compounds, reactions
#   are expected to fail given a priori knowledge of how
#   the importer is working and what objects are problematic.
#   This is represented as a hashref with the following structure:
#
#    {
#        reaction => [ 'rxn12345', rxn12346', ...],
#        compound => [ 'cpd00001', ... ],
#    }
#

has 'expectedFailure' =>
    (is => 'rw', isa => 'HashRef', default => sub { return {}; });
has 'efFile' => (is => 'rw', isa => 'Str');

sub BUILD {
    my ($self) = @_;
    if (defined($self->efFile) && -f abs_path($self->efFile)) {
        $self->load_ef_from_file(abs_path($self->efFile));
    }
}

# explanation
sub check {
    my ($self, $header, $time, $missed) = @_;
    $self->logger->info("$header in $time seconds\n");
    $self->logger->info("==== Begin Errors ====\n");
    foreach my $type (keys %$missed) {
        if (ref($missed->{$type}) eq 'ARRAY') {
            map { $self->checkObject($type, $_) } @{$missed->{$type}};
        } else {
            while (my ($id, $explanation) = each %{$missed->{$type}}) {
                $self->checkObject($type, $id, $explanation);
            }
        }
    }
    $self->logger->info("==== End Errors   ====\n");

}

sub checkObject {
    my ($self, $type, $id, $explanation) = @_;
    my $expected = $self->expectedFailure->{$type};
    if (defined($expected) && $id ~~ @$expected) {
        return;
    } else {
        $self->warnObject($type, $id, $explanation);
    }
}

sub warnObject {
    my ($self, $type, $id, $explanation) = @_;
    $explanation = "\n\t$explanation" if defined $explanation;
    $explanation = "" unless defined $explanation;
    $self->logger->info(
        "Failed to create object [$type]: $id;\n$explanation");
}

sub load_ef_from_file {
    my ($self, $efFile) = @_;
    my $j    = JSON::Any->new();
    my $text = File::Slurp::read_file($efFile);
    $self->expectedFailure($j->jsonToObj($text));
}

1;
