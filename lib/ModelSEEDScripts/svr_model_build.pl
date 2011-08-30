use strict;

use Getopt::Long;
use Pod::Usage qw(pod2usage);
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#



my ($user, $password, $source, $media, $man, $help, $owner) = undef;
$user = $ENV{'SAS_USER'} if(defined($ENV{'SAS_USER'}));
$password = $ENV{'SAS_PASSWORD'} if(defined($ENV{'SAS_PASSWORD'}));
my $nogapfilling = 0;
my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'media' => \$media,
                          'source|s' => \$source,
                          'nogapfill' => \$nogapfilling,
                          'owner|s' => \$owner,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
my $id = shift @ARGV;
pod2usage(1) if(not defined($id));
my $arguments = {id => $id};
lc $source;
if($source eq 'rast' || $source eq 'pubseed') {
    $arguments->{'source'} = $source;
} elsif(defined($source)) {
    warn "Invalid source. Can be 'rast' or 'pubseed'.\n";
    pod2usage(1);
}
if(defined($user) && defined($password)) {
    $arguments->{'username'} = $user;
    $arguments->{'password'} = $password;
}

if(defined($owner)) {
    $arguments->{'owner'} = $owner;
}

$arguments->{'media'} = $media if defined($media);
$arguments->{'gapfilling'} = ($nogapfilling == 1) ? 0 : 1;

my $fba = new FBAMODELserver;
my $result = $fba->model_build($arguments);
if(defined($result->{-error})) {
    warn $result->{-error} . "\n";
}
print $result->{id} . "\n";

__DATA__

=head1 SYNOPSIS

svr_model_build genomeId [options] 

=head2 OPTIONS 

=over 4

=item username

If provided along with password, also returns private models.

=item password 

=item source [rast || pubseed]

Forces the model construction pipeline to use either RAST or PubSEED
genome. Otherwise, the pipeline will select the first matching genome
ID that it finds.

=item nogapfilling

If supplied, the model will not be gapfilled. Only a preliminary
reconstruction will be done. In all likelyhood, the model will not grow
with this.

=item media [media_name]

Define the gapfilling media to use. 

=back

=head2 DESCRIPTION

Returns a model Id which WILL BE the model when it is done. Use
svr_model_status to determine whether the model has been constructed
and gapfilled.

=cut
