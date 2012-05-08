# Testing Reaction object
use strict;
use warnings;
use Test::More;
use JSON::Any;
use ModelSEED::MS::Reaction;
use File::Basename;
use Data::Dumper;
use Clone qw(clone);
use List::Util qw(shuffle);
my $testCount = 0;
my $REACTIONS_TO_TEST = 1000;

my $reactions = [];
{
    # Need to have biochemistry-data.json file in same directory as this test.
    my $dataFile = File::Basename::dirname(__FILE__)."/biochemistry-object.json";
    ok -f $dataFile, "Could not find $dataFile that contains biochemistry data!";
    local $/;
    open(my $fh, "<", $dataFile) || die("Could not open file $dataFile: $!");
    my $text = <$fh>;
    close($fh);
    my $j = JSON::Any->new(utf8 => 1);
    my $data = $j->from_json($text);
    ok defined($data->{relationships}->{reactions}), "biochemistry-object has reactions";
    ok @{$data->{relationships}->{reactions}} > 0, "biochemistry-object has reactions"; 

    $testCount += 3;
    my @rxns = shuffle(@{$data->{relationships}->{reactions}});
    splice( @rxns, $REACTIONS_TO_TEST);
    foreach my $rxn (@rxns) {
        my $obj = ModelSEED::MS::Reaction->new($rxn);
        ok defined($obj), "Created object for " . Dumper($rxn);
        push(@$reactions, $obj);
        $testCount += 1;
    }
}

# Test basic interface functions
{
   foreach my $rxn (@$reactions) {
       ok defined $rxn->uuid, "Should have uuid";
       ok defined $rxn->modDate, "Should have modDate";
       ok defined $rxn->name, "Should have name";
       ok defined $rxn->equation, "Should have equation";
       $testCount += 4;
   }
}

# Test serializeToDB for some reactions
{
    foreach my $rxn (@$reactions) {
        my $serialOne = $rxn->serializeToDB();
        my $clone = clone($serialOne);
        my $rxnTwo = ModelSEED::MS::Reaction->new($clone);
        my $serialTwo = $rxnTwo->serializeToDB();
        is_deeply $serialTwo, $serialOne, "serialize should have round trip integrity";
        $testCount += 1;
   }
}

done_testing($testCount);

