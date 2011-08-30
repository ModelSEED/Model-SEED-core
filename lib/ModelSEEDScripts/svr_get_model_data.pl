use strict;

use Getopt::Long;
use Pod::Usage;
use SeedEnv;
use FBAMODELserver;

#
# This is a SAS Component
#

my ($help, $man, $model, $user, $password, $column, $doHeader) = undef;
my $opted    = GetOptions('u|username|user=s' => \$user,
                          'p|password=s' => \$password,
                          'column=i' => \$column,
                          'help|?'  => \$help,
                          'man'     => \$man,
                          'header|h' => \$doHeader,
                        ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

my $fba = new FBAMODELserver;
# Getting models (From argument and/or STDIN
my $models = [];
my $lines  = [];
unless(-t STDIN) { # Read model ids in from STDIN unless STDIN is tty, i.e. the shell
    while(my @tmp = ScriptThing::GetBatch(\*STDIN, undef, $column)) {
        push(@$models, map { $_->[0] } @tmp);
        push(@$lines, @tmp);
    }
}
# Setting arguments to server call
my $args = {'id' => $models};
if($password ne "" && $user ne "") {
    $args->{password} = $password;
    $args->{user} = $user;
}
my $ret = $fba->get_model_data($args);
# Output content
my $header = ['Id', 'Genome', 'Name', 'Source'];
if($doHeader) {
    print join("\t", @$header);
}

foreach my $model (keys %$ret) { 
    print printModel($ret->{$model}, $header) . "\n"; 
}

sub printModel {
    my ($rxnObj, $header) = @_;
    my $string = [];
    foreach my $key (@$header) {
        my $column = $rxnObj->{$key};
        if(defined($rxnObj->{$key})) {
            push(@$string, $column); 
        } else {
            push(@$string, "");
        }
    }
    return join("\t", @$string);
}


__DATA__

=head1 SYNOPSIS

svr_get_model_data [options] [< modelIdFile] > output

Options:

  -help      Prints simple usage options
  -man       Prints manual page
  -header    Print a header on the output file
  -user      
  -password

=head2 DESCRIPTION

Returns model information in a tab-deliminated table form. You must
pass in a file containing one model ID per line. Use B<-header> to print
out column headers. There will always be the following headers:

=over 4
=item B<Genome> : The model id

=item B<Name> : The model name.

=item B<Source> : The source of the model, e.g. a PubMed Id

=back 


To make this more readable, you may output a header field with B<-header>.
If you are trying to access private models, it is neccesary to input
your username B<-user> and password B<-password>.

=cut
