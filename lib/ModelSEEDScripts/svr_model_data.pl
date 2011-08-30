use strict;

use Getopt::Long;
use Pod::Usage qw(pod2usage);
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#

my ($user, $password, $fields, $man, $help, $verbose, $directory) = undef;
# Get password from user env
$user = $ENV{'SAS_USER'} if defined($ENV{'SAS_USER'});
$password = $ENV{'SAS_PASSWORD'} if defined($ENV{'SAS_PASSWORD'});

my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password,
                          'directory|d=s' => \$directory,
                          'field|f=s@' => \$fields,
                        ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
my $fba = new FBAMODELserver;
my $args = {'-roles' => 1};
# Process password from command line
if(defined($user) && defined($password)) {
    $args->{'user'} = $user;
    $args->{'password'} = $password;
}
my $ids = [];
my $outs = [];
if(@ARGV > 0) {
    push(@$ids, shift @ARGV);
    push(@$outs, \*STDOUT);
}
# Batch input "model_id    output_file"
if( !-t STDIN ) {
    while(<STDIN>) {
        my @parts = split(/\t/, $_);
        map { chomp $_; } @parts;
        if(@parts == 1) {
            push(@parts, $parts[0]);
        }
        push(@{$ids}, $parts[0]);
        push(@{$outs}, $parts[1]);
    }
}
if(defined($directory) && -d $directory) {
    chdir $directory;
}
for(my $i=0; $i<@$ids; $i++) {
    my $fh = $outs->[$i];
    if(ref($fh) ne 'GLOB') {
        if(-e $fh) {
            warn "File $fh already exists, skipping!\n";
            next;
        }
        my $filename = $fh;
        $fh = undef;
        open($fh, ">", $filename);
    }
    $args->{id} = $ids->[$i];
    my $result = $fba->get_model_reaction_data($args);
    if(defined($result->{'error'})) {
        warn $result->{'error'} . "\n";
    }
    my $data = $result->{data};
    my $headings = $result->{headings};
    if(!defined($fields) || scalar(@$fields) == 0) {
        my @tmp = sort @$headings;
        $fields = \@tmp;
    }
    print $fh join("\t", sort @$fields) . "\n";
    for my $row (@$data) {
        my $out_row = [];
        for my $column_name (@$fields) {
            my $column = $row->{$column_name} || [];
            push(@$out_row, join(",", @$column));
        }
        print $fh join("\t", @$out_row) . "\n";
    }
}

__DATA__

=head1 SYNOPSIS

svr_model_data [options] model_id > output

=head2 OPTIONS 

=over 4

=item field [-f]
Optional. Limit the results to specific fields. You may string together any
number of these. E.g. -f pegs -f roles -f equation

=item directory [-d]

If using the batch mode method, this changes the current working directory
before saving files.

=item username [-u]

Required. If the environment variable "SAS_USER" is defined, this defaults
to that username. You may still override that with the --username flag.

=item password [-p]

Required. If the enviornment variable "SAS_PASSWORD" is defined, this
defaults to that password. You may still override that with the --password flag.

=back

=head2 DESCRIPTION

Returns a tab-delimited table of model reaction data. Note that there is
a batch-run mode of this script which takes as input on standard in a tab-delimited
table of [model_id, output_file] on each line. The details of each model are then
downloaded and saved to the output_file. Note that if the file already exists, this
will raise an error and stop.

=cut
