use strict;

use Getopt::Long;
use Pod::Usage qw(pod2usage);
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#


my ($user, $password, $man, $help) = undef;
$user = $ENV{'SAS_USER'} if(defined($ENV{'SAS_USER'}));
$password = $ENV{'SAS_PASSWORD'} if(defined($ENV{'SAS_PASSWORD'}));
my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
unless(defined($user) && defined($password)) {
    warn "You must provide a username and passsword!\n";
    pod2usage(2);
}

my $fba = new FBAMODELserver;
my $models;
if($password && $user) {
    $models = $fba->get_model_id_list({ user => $user, password => $password, 'onlyMine' => 1});
} else {
    $models = $fba->get_model_id_list();
}
foreach my $id (@$models) {
    print "$id\n";
}

__DATA__

=head1 SYNOPSIS

svr_my_models [options] > output

=head2 OPTIONS 

=over 4

=item username [-u]

Required. If the environment variable "SAS_USER" is defined, this defaults
to that username. You may still override that with the --username flag.

=item password [-p]

Required. If the enviornment variable "SAS_PASSWORD" is defined, this
defaults to that password. You may still override that with the --password flag.

=back

=head2 DESCRIPTION

Returns a list of model Ids that are owned by the user. One per line.

=cut
