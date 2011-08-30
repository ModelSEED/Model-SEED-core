use strict;

use Cwd;
use Getopt::Long;
use Pod::Usage qw(pod2usage);
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#

my ($user, $password, $field, $man, $help, $verbose, $directory) = undef;
# Get password from user env
$user = $ENV{'SAS_USER'} if defined($ENV{'SAS_USER'});
$password = $ENV{'SAS_PASSWORD'} if defined($ENV{'SAS_PASSWORD'});

my $opted    = GetOptions('help|h|?' => \$help,
                          'man|m' => \$man,
                          'u|username|user=s' => \$user,
                          'p|password=s' => \$password,
                          'directory|d=s' => \$directory,
                          'field|f=s' => \$field,
                        ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
my $fba = new FBAMODELserver;
my $args = {};
# Process password from command line
if(defined($user) && defined($password)) {
    $args->{'user'} = $user;
    $args->{'password'} = $password;
}

my $a = [];
my $b = [];
my $out = [];
if(@ARGV > 1) {
    push(@$a, shift @ARGV);
    push(@$b, shift @ARGV);
    push(@$out, \*STDOUT);
}
# Batch input "modelone     modeltwo    output_file"
if( !-t STDIN ) {
    while(<STDIN>) {
        my @parts = split(/\t/, $_);
        map { chomp $_; } @parts;
        if(@parts < 3) {
            warn "Invalid use of batch mode on line $. of file!\n";
            next;
        }
        push(@{$a}, $parts[0]);
        push(@{$b}, $parts[1]);
        push(@$out, $parts[2]);
    }
}
for(my $i=0; $i<@$a; $i++) {
    my $cwd = cwd();
    my $curr_a = $a->[$i];
    my $curr_b = $b->[$i];
    my $curr_out = $out->[$i];
    if(!-f $curr_a) {
        $args->{id} = $curr_a;
        my $result = $fba->get_model_reaction_data($args);
        if(defined($result->{'error'})) {
            warn $result->{'error'} . "\n";
            next;
        }
        $curr_a = $result->{data};
    } else {
        open(my $tmp, "<", $curr_a);
        $curr_a = to_data($tmp);
    }
    if(!-f $curr_b) {
        $args->{id} = $curr_b;
        my $result = $fba->get_model_reaction_data($args);
        if(defined($result->{'error'})) {
            warn $result->{'error'} . "\n";
            next;
        }
        $curr_b = $result->{data};
    } else {
        open(my $tmp, "<", $curr_b);
        $curr_b = to_data($tmp);
    }
    $field = 'DATABASE' if (!defined($field));
    my $curr_a_hash = hash_data($curr_a, $field);
    my $curr_b_hash = hash_data($curr_b, $field);
    chdir $directory if(defined($directory) && -d $directory);
    if(ref($curr_out) ne 'GLOB') {
        if(-e $curr_out) {
            warn "File $curr_out already exists, skipping!\n";
            next;
        }
        my $outfile = $curr_out;
        $curr_out = undef;
        open($curr_out, "<", $outfile);
    }
    my $both = {};
    foreach my $key (keys %$curr_a_hash) {
        if(defined($curr_b_hash->{$key})) {
            my $b_val = $curr_b_hash->{$key};
            my $a_val = $curr_a_hash->{$key};
            delete $curr_b_hash->{$key};
            delete $curr_a_hash->{$key};
            $both->{$key} = [$b_val, $a_val];
        }
    }
    print_output($curr_out, $curr_a_hash, $both, $curr_b_hash);
    chdir $cwd;  
}

sub print_output {
    my ($fh, $a, $both, $b) = @_;
    my @all = keys %$a;
    push(@all, keys %$b);
    push(@all, keys %$both);
    warn Dumper($fh);
    foreach my $k (sort @all) {
        if(defined($a->{$k})) {
            print $fh "-" . $a->{$k} ."\n";
        } elsif(defined($b->{$k})) {
            print $fh "+" . $b->{$k} . "\n";
        } else {
#            print $fh " " . $both->{$k}->[0] . "\n";
        }
    } 
}

sub hash_data {
    my ($data, $field) = @_;    
    my $out_hash = {};
    for(my $i=0; $i<@$data; $i++) {
        my $row = $data->[$i];
        my $col = $row->{$field};
        next unless(defined($col) && @$col > 0);
        for(my $j=0; $j<@$col; $j++) {
            my $key = $col->[$j];
            $out_hash->{$key} = $key;
        }
    }        
    return $out_hash;
}

sub to_data {
    my ($fh) = @_;
    my $data = [];
    my $headings;
    while(<$fh>) {
        my @row = split(/\t/, $_);
        map { chomp $_; } @row;
        if(not defined($headings)) {
            $headings = {};
            for(my $i=0; $i<@row; $i++) {
                $headings->{$i} = $row[$i];
            }        
        } else {
            my $out_row = {};
            for(my $i=0; $i<@row; $i++) {
               $out_row->{$headings->{$i}} = [split(/,/, $row[$i])];
            }
            push(@$data, $out_row);
        }
    }
    return $data;
}

__DATA__

=head1 SYNOPSIS

svr_model_diff [options] modelOne modelTwo > output

=head2 OPTIONS 

=over 4

=item field [-f]
Specify a field to produce diff results over.

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

=cut
