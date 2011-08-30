use strict;
use Getopt::Long;
use Pod::Usage qw(pod2usage);
use File::Path qw(mkpath);
use SeedEnv;
use ModelDBserver;

#
# This is a SAS Component
#

my ($user, $password, $directory, $man, $help, $verbose) = undef;
my $args = {};
my $delimiter = "\t";
# Get password from user env
$args->{user} = $ENV{'SAS_USER'} if defined($ENV{'SAS_USER'});
$args->{password} = $ENV{'SAS_PASSWORD'} if defined($ENV{'SAS_PASSWORD'});

my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password,
                          'd|directory=s' => \$directory,
                        ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
my $db = new ModelDBserver;
unless(defined($directory)) {
    warn "You must supply a directory to print the files into with -d option.\n";
    pod2usage(2);
}

# Process password from command line
if(defined($user) && defined($password)) {
    $args->{'user'} = $user;
    $args->{'password'} = $password;
}
# Append trailing slash if it wasn't provided
if($directory !~ /\/$/) {
    $directory .= '/';
}
# Create the directory path if it does not already exist:
unless(-d $directory) {
    mkpath($directory);
}
my @types = qw(strFtr strExp strFtrAls strIntFtr strInt strStrain strPrimer strPheno strPred strStrInt);
foreach my $type (@types) {
    if(-e $directory.$type.'.txt') {
        warn $directory.$type.".txt already exists and will not be overwritten!\nPlease move or delete this file and rerun the script.\n";
        next;
    }
    open (my $fh, ">", $directory.$type.'.txt') || die($@);
    $args->{type} = $type;
    $args->{query} = {};
    my $response = $db->get_objects($args);
    if($response->{success} eq 'false' || $response->{failure} eq 'true') {
        warn "Database query for type $type failed with error: " . $response->{msg} . "\n";
        next;
    }
    my $objects = $response->{response}; 
    # get headings
    my $headings = {};
    foreach my $object (@$objects) {
        foreach my $key (keys %$object) {
            $headings->{$key} = 1;
        }
    }
    print $fh join($delimiter, sort keys %$headings) . "\n";
    foreach my $object (@$objects) {
        my @heading_copy = sort keys %$headings;
        print $fh join($delimiter, map { $_ = $object->{$_} || "" } @heading_copy ) . "\n";
    }
    close($fh);
    print "Saved ".scalar(@$objects)." rows of $type data into file ".$directory.$type.".txt\n";
}

__DATA__

=head1 SYNOPSIS

strain_database_dump [options] 

=head2 OPTIONS 

=over 4

=item username [-u]

Required to return "private" strain data. If an administrator username
and password is provided, this will return all strain data.

=item password [-p]

=item directory [-d] (Required)

Path to directory where this script will output flat table files for
each database table.

=item help [-h]

Displays this help information.

=back

=head2 DESCRIPTION

Produces a set of tab-delimited table files in the specified directory
correspoding to the current information in the ModelSEED strain databases.

=cut
