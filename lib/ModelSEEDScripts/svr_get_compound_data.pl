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
                          'model=s' => \$model,
                          'column=i' => \$column,
                          'help|?'  => \$help,
                          'man'     => \$man,
                          'header|h' => \$doHeader,
                        ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

my $fba = new FBAMODELserver;
# Getting models (From argument and/or STDIN
my $compounds = [];
my @models;
if(defined($model)) {
    @models = split(/,/, $model);
}
my $lines  = [];
unless(-t STDIN) { # Read model ids in from STDIN unless STDIN is tty, i.e. the shell
    while(my @tmp = ScriptThing::GetBatch(\*STDIN, undef, $column)) {
        push(@$compounds, map { $_->[0] } @tmp);
        push(@$lines, @tmp);
    }
}
# Setting arguments to server call
my $args = {'id' => $compounds};
if($password ne "" && $user ne "") {
    $args->{password} = $password;
    $args->{user} = $user;
}
if(@models > 0) {
    $args->{model} = \@models;
} 
my $ret = $fba->get_compound_data($args);
# Output content
my $header = makeHeader($ret, \@models);
if($doHeader) {
    print join("\t", @$header);
}

foreach my $rxnId (keys %$ret) { 
    print printReaction($ret->{$rxnId}, $header) . "\n"; 
}

sub makeHeader {
    my ($ret, $models) = @_;
    my %unverifiedModels = map { $_ => 1 } @$models;
    my $verifiedModels = {};
    my $header = ['DATABASE', 'NAME', 'FORMULA', 'MASS', 'CHARGE', 'KEGGID', 'DELTAG', 'DELTAGERR', 'STRINGCODE'];
    foreach my $rxnObj (values %$ret) {
        foreach my $key (keys %$rxnObj) {
            if(defined($unverifiedModels{$key})) {
                $verifiedModels->{$key} = 1;
            }
        }
    }
    push(@$header, sort keys %$verifiedModels);
    return $header;
} 

sub printReaction {
    my ($rxnObj, $header) = @_;
    my $string = [];
    foreach my $key (@$header) {
        my $column = $rxnObj->{$key};
        if(defined($column) && ref($column) eq 'HASH') {
            my $com = join(',',@{$column->{'COMPARTMENTS'}})    || ""; 
            push(@$string, "$com");
        } elsif(defined($column)) {
           push(@$string, join(',', @$column)); 
        } else {
           push(@$string, ""); 
        }
    }
    return join("\t", @$string);
}


__DATA__

=head1 SYNOPSIS

svr_get_compound_data [options] [< compoundIdFile] > output

Options:

  -help      Prints simple usage options
  -man       Prints manual page
  -model     A single modelID or a comma deliminated list of models
  -column    The column in input containing compound Id
  -header    Print a header on the output file
  -user      
  -password

=head2 DESCRIPTION

Returns compound information in a tab-deliminated table form. You must
pass in a file containing one compound per line. Use B<-header> to print
out column headers. There will always be the following headers:

=over 4

=item B<DATABASE> : The compound id

=item B<NAME> : The compound name.

=item B<MASS> : The compound's atomic mass.

=item B<CHARGE> : The calculated chage of the compound at 7pH.

=item B<KEGGID> : The Kyoto Encyclopedia of Genes and Genomes (KEGG) compound ID

=item B<DELTAG> : The Gibbs free energy change of the compound.

=item B<DELTAGERR> : The uncertainty of the DELTAG calculation.

=item B<STRINGCODE> : Compound structure using string-code method.

=back 

Additionally, each model supplied with the B<-model> argument (comma
deliminated lists allowed) will generate a column containing information
about each compound:

=over 4

=item B<Compartments>

Which compartments the compound can be found in. This is a comma deliminated list.

=back

To make this more readable, you may output a header field with B<-header>.
If you are trying to access private compounds or private models, it is
neccesary to input your username B<-user> and password B<-password>.

=cut
