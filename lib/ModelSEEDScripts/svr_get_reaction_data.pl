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
my $reactions = [];
my @models = split(/,/, $model) || ();
print @models;
my $lines  = [];
unless(-t STDIN) { # Read model ids in from STDIN unless STDIN is tty, i.e. the shell
    while(my @tmp = ScriptThing::GetBatch(\*STDIN, undef, $column)) {
        push(@$reactions, map { $_->[0] } @tmp);
        push(@$lines, @tmp);
    }
}
# Setting arguments to server call
my $args = {'id' => $reactions};
if($password ne "" && $user ne "") {
    $args->{password} = $password;
    $args->{user} = $user;
}
if(@models > 0) {
    $args->{model} = \@models;
} 
my $ret = $fba->get_reaction_data($args);
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
    my $header = ['DATABASE', 'EQUATION', 'REVERSIBILITY', 'DELTAG', 'DELTAGERR', 'PATHWAY', 'KEGG MAPS'];
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
            my $dir = join(',',@{$column->{'DIRECTIONALITY'}}) || "";
            my $com = join(',',@{$column->{'COMPARTMENT'}})    || ""; 
            my $peg = join(',',@{$column->{'ASSOCIATED PEG'}}) || "";
            push(@$string, "$dir|$com|$peg");
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

svr_get_reaction_data [options] [< reactionIdFile] > output

Options:

  -help      Prints simple usage options
  -man       Prints manual page
  -model     A single modelID or a comma deliminated list of models
  -column    The column in input containing reaction Id
  -header    Print a header on the output file
  -user      
  -password

=head2 DESCRIPTION

Returns reaction information in a tab-deliminated table form. You must
pass in a file containing one reaction per line. Use B<-header> to print
out column headers. There will always be the following headers:

=over 4

=item B<DATABASE> : The reaction id

=item B<EQUATION> : The equation, containing compound Ids.

=item B<REVERSIBILITY> : This is the thermodynamic reversibility of the
reaction as calculated in the Model SEED.

=item B<DELTAG> : The Gibbs free energy change of the reaction.

=item B<DELTAGERR> : The uncertainty of the DELTAG calculation.

=item B<PATHWAY> : The Kyoto Encyclopedia of Genes and Genomes (KEGG)
pathway name for the reaction. A comma deliminated list

=item B<KEGG MAP> : The KEGG map ids, A comma deliminated list

=back 

Additionally, each model supplied with the B<-model> argument (comma
deliminated lists allowed) will generate a column containing information
about each reaction in a "|" (pipe) deliminted list. There are three
fields:

=over 4

=item B<Directionality> : The directionality of the reaction that the model implements.

=item B<Compartment>

What compartment the reaction takes place in.  Transport reactions
usually annotate compounds cpd00010[e] for different compartments,
with all other compounds in the 'default' compartment.

=item B<Associated Pegs>

This is the set of protien encoding genes (PEG) that are associated with
implementing this reaciton.  Usually this is a ',' (comma) or '+' (plus)
deliminated list where '+' (plus) usually implies a protein complex.

=back

To make this more readable, you may output a header field with B<-header>.
If you are trying to access private reactions or private models, it is
neccesary to input your username B<-user> and password B<-password>.

=cut
