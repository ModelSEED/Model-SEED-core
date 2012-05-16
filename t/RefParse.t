use ModelSEED::RefParse;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
my $test_count = 0;

my $refs = [
    "http://model-api.theseed.org/biochemistry/chenry/master",
    "http://model-api.theseed.org/biochemistry/550e8400-e29b-41d4-a716-446655440000",
    "http://model-api.theseed.org/biochemistry/chenry/master/reactions",
    "http://model-api.theseed.org/biochemistry/chenry/master/reactions/550e8400-e29b-41d4-a716-446655440000",
    "http://model-api.theseed.org/biochemistry/550e8400-e29b-41d4-a716-446655440000/reactions",
    "biochemistry/chenry/master",
    "biochemistry/550e8400-e29b-41d4-a716-446655440000",
    "http://model-api.theseed.org/biochemistry/chenry/master",
];
my $parser = ModelSEED::RefParse->new();

foreach my $ref (@$refs) {
    print Dumper $parser->parse($ref);
}

done_testing($test_count);
