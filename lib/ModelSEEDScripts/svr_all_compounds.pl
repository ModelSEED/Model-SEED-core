use strict;

use Getopt::Long;
use Pod::Usage;
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#

my ($help, $man, $model, $user, $password, $column) = undef;
my $opted    = GetOptions('u|username|user=s' => \$user,
                          'p|password=s' => \$password,
                          'model=s' => \$model,
                          'modelids=i' => \$column,
                          'help|?'  => \$help,
                          'man'     => \$man,
                        ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

my $fba = new FBAMODELserver;
# Getting models (From argument and/or STDIN
my $models = [];
my $lines  = [];
push(@$models, $model) if(defined($model));
unless(-t STDIN) { # Read model ids in from STDIN unless STDIN is tty, i.e. the shell
    while(my @tmp = ScriptThing::GetBatch(\*STDIN, undef, $column)) {
        push(@$models, map { $_->[0] } @tmp);
        push(@$lines, @tmp);
    }
}
# Setting arguments to server call
my $args = {};
if($password ne "" && $user ne "") {
    $args->{password} = $password;
    $args->{user} = $user;
}
if(scalar(@$models) > 0) {
    $args->{id} = $models;
} 
my $ret = $fba->get_compound_id_list($args);
# Output content
if(defined($ret->{'ALL'})) {
    foreach my $id (@{$ret->{'ALL'}}) { 
        print "$id\n";
    }
} elsif(scalar(@$lines) > 0) {
    foreach my $line (@$lines) {
        my $cpds = $ret->{$line->[0]} || [];
        print $line->[1] . "\t" . join(',', @$cpds) . "\n";
    }
} else {
    $model = $models->[0];
    my $cpds = $ret->{$model} || [];
    foreach my $cpd (@$cpds) {
        print $cpd . "\n";
    }
}

__DATA__

=head1 SYNOPSIS

svr_all_compounds [options] [< modelIDFile] > output

Options:

  -help      Prints simple usage options
  -man       Prints manual page
  -model     A single modelID
  -column    The column in input containing modelId
  -user      
  -password

=head2 OPTIONS

=over 4

=item B<-help>

Prints help message and exits.

=item B<-man>

Prints man page and exits.

=item B<-model>

A model ID, returns only compound ids for that model.

=item B<-column>

The column in STDIN containing model ID

=item B<-user>

Your username.

=item B<-password>

Your password.

=back

=head2 DESCRIPTION

Returns a list of compound IDs. If no arguments are supplied, returns
the complete list of all compound IDs, one ID per line. If a model ID
is supplied with the B<-model> option, this will only return compounds
that are present in that model. If a file is supplied to Standard Input
with model IDs in the last column, this appends compound IDs to the line,
comma delimited. The option B<-column> specifies a column for extracting
the model ID (first column is 1). To retrive model compounds for a private
model B<-user> and B<-password> must be supplied. Private compounds must
also include this authentication.

=cut
