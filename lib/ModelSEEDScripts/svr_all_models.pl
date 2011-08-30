use strict;

use Getopt::Long;
use Pod::Usage qw(pod2usage);
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#



my ($user, $password, $man, $help) = undef;
my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
my $fba = new FBAMODELserver;
my $models;
if($password && $user) {
    $models = $fba->get_model_id_list({ user => $user, password => $password });
} else {
    $models = $fba->get_model_id_list();
}
foreach my $id (@$models) {
    print "$id\n";
}

__DATA__

=head1 SYNOPSIS

svr_all_models [options] > output

=head2 OPTIONS 

=over 4

=item username

If provided along with password, also returns private models.

=item password 

=back

=head2 DESCRIPTION

Returns a list of model IDs, one per line. If Username and Password are
provided, this will also return private models for that user.

=cut
