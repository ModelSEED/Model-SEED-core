use strict;

use Getopt::Long;
use Pod::Usage qw(pod2usage);
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#

my ($user, $password, $fields, $man, $help, $verbose) = undef;
# Get password from user env
$user = $ENV{'SAS_USER'} if defined($ENV{'SAS_USER'});
$password = $ENV{'SAS_PASSWORD'} if defined($ENV{'SAS_PASSWORD'});

my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password,
                          'field|f=s@' => \$fields,
                        ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
my $fba = new FBAMODELserver;
my $args = {id => []};
# Process password from command line
if(defined($user) && defined($password)) {
    $args->{'user'} = $user;
    $args->{'password'} = $password;
}
# Get models from either command line or a set of files
foreach my $arg (shift @ARGV) {
    next unless(defined($arg) && $arg ne '');
    if(-e $arg) {
       # TODO validate model directory and get id
    } else {
        push(@{$args->{id}}, $arg);
    }
}
# Get model ids from standard input if it's actually there
if( !-t STDIN ) {
    while(<STDIN>) {
        chomp $_;
        push(@{$args->{id}}, $_);
    }
}
my $result = $fba->get_model_stats($args);

if(defined($result->{'error'})) {
    warn $result->{'error'} . "\n";
}
my $data = $result->{data};
if(!defined($fields) || scalar(@$fields) == 0) {
    my @tmp = sort keys %{$data->[0]};
    $fields = \@tmp;
}
if(@$data > 1) {
    print join("\t", sort @$fields) . "\n";
    for my $mdl (@$data) {
        my @field_cp = @$fields;
        print join("\t", map { $_ = $mdl->{$_} } sort @field_cp) . "\n";
    }
} elsif(@$data == 1) {
    for my $attr (sort @$fields) {
        print $attr . "\t" . $data->[0]->{$attr} . "\n";
    }
}

__DATA__

=head1 SYNOPSIS

svr_model_stats [options] [model_id ...] > output

=head2 OPTIONS 

=over 4

=item username

If provided along with password, also returns private models.

=item password 


=back

=head2 DESCRIPTION

Returns detailed statistics on a model or list of models. If more than one
model is provided, returns it as a tab delimited table.  Otherwise returns
a list of key-value pairs.

=cut
