use strict;

use Getopt::Long;
use Pod::Usage qw(pod2usage);
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#

my ($user, $password, $man, $help, $verbose) = undef;
# Get password from user env
$user = $ENV{'SAS_USER'} if defined($ENV{'SAS_USER'});
$password = $ENV{'SAS_PASSWORD'} if defined($ENV{'SAS_PASSWORD'});

my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'v|verbose' => \$verbose,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
my $fba = new FBAMODELserver;
my $args = {models => []};
# Process password from command line
if(defined($user) && defined($password)) {
    $args->{'user'} = $user;
    $args->{'password'} = $password;
}
# Get models from either command line or a set of files
foreach my $arg (shift @ARGV) {
    if(-f $arg) {
        
    } else {
        push(@{$args->{models}}, $arg);
    }
}
    
my $result = $fba->model_status($args);

if(defined($result->{'-error'})) {
    warn $result->{'-error'} . "\n";
}

my @headers = ('id', 'status');
if($verbose) {
   @headers = sort keys %{$result->{'models'}->[0]};
}
print join("\t", @headers) . "\n" if($verbose);
foreach my $model (@{$result->{'models'}}) {
    my $row = [];
    foreach my $header (@headers) {
        push(@$row, $model->{$header});
    }
    print join("\t", @$row) . "\n"; 
}

__DATA__

=head1 SYNOPSIS

svr_model_status [options] [model_id ...] > output

=head2 OPTIONS 

=over 4

=item verbose [-v]

Outputs more details about each model.

=item username

If provided along with password, also returns private models.

=item password 


=back

=head2 DESCRIPTION

Returns the current status on a model or list of models. 
Models may be specified either on the command line separated by spaces or
in a filename separated by newlines.

=cut
