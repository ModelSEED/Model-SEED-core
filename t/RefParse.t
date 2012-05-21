use ModelSEED::RefParse;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
my $test_count = 0;

my $refs = {
    "http://model-api.theseed.org/biochemistry/chenry/master" => {
        type => 'object',
        class => 'ModelSEED::MS::Biochemistry',
        base => "biochemistry",
        base_types => [ 'biochemistry' ],
        id => 'chenry/master',
        id_type => 'alias',
        parent_objects => [],
        parent_collections => [ "biochemistry" ],
    },
    "http://model-api.theseed.org/biochemistry/550e8400-e29b-41d4-a716-446655440000" => {
        type => 'object',
        class => 'ModelSEED::MS::Biochemistry',
        base => "biochemistry",
        base_types => [ 'biochemistry' ],
        id => "550e8400-e29b-41d4-a716-446655440000",
        id_type => 'uuid',
        parent_objects => [],
        parent_collections => [ "biochemistry" ],
    },
    "http://model-api.theseed.org/biochemistry/chenry/master/reactions" => {
        type => 'collection',
        class => "ModelSEED::MS::Reaction",
        base => "biochemistry/chenry/master",
        base_types => [ 'biochemistry', 'reactions' ],
        parent_objects => [ "biochemistry/chenry/master" ],
        parent_collections => [ "biochemistry"],
    },
    "http://model-api.theseed.org/biochemistry/chenry/master/reactions/550e8400-e29b-41d4-a716-446655440000" => {
        type => "object",
        class => "ModelSEED::MS::Reaction",
        base => "biochemistry/chenry/master/reactions",
        base_types => [ 'biochemistry', 'reactions' ],
        id => "550e8400-e29b-41d4-a716-446655440000",
        id_type => 'uuid',
        parent_objects => [ "biochemistry/chenry/master" ],
        parent_collections => [ "biochemistry", "biochemistry/chenry/master/reactions" ],
    },
    "http://model-api.theseed.org/biochemistry/550e8400-e29b-41d4-a716-446655440000/reactions" => {
        type => "collection",
        base => "biochemistry/550e8400-e29b-41d4-a716-446655440000",
        base_types => [ 'biochemistry', 'reactions' ],
        class => "ModelSEED::MS::Reaction",
        parent_objects => [ "biochemistry/550e8400-e29b-41d4-a716-446655440000" ],
        parent_collections => [ "biochemistry" ],
    },
    "biochemistry/chenry/master" => {
        type => "object",
        id => "chenry/master",
        id_type => 'alias',
        class => "ModelSEED::MS::Biochemistry",
        base => "biochemistry",
        base_types => [ 'biochemistry' ],
        parent_objects => [],
        parent_collections => [ "biochemistry" ],
    },
    "biochemistry/550e8400-e29b-41d4-a716-446655440000" => {
        type => "object",
        id => "550e8400-e29b-41d4-a716-446655440000",
        id_type => 'uuid',
        class => "ModelSEED::MS::Biochemistry",
        base => "biochemistry",
        base_types => [ 'biochemistry' ],
        parent_objects => [],
        parent_collections => [ "biochemistry" ],
    },
    "http://model-api.theseed.org/biochemistry/chenry/master" => {
        type => "object",
        id => "chenry/master",
        id_type => 'alias',
        class => "ModelSEED::MS::Biochemistry",
        base => "biochemistry",
        base_types => [ 'biochemistry' ],
        parent_objects => [],
        parent_collections => [ "biochemistry" ],
    },
    "biochemistry" => {
        type => "collection",
        class => "ModelSEED::MS::Biochemistry",
        base_types => [ 'biochemistry' ],
        parent_objects => [],
        parent_collections => [],
    }
};
my $parser = ModelSEED::RefParse->new();

foreach my $ref (keys %$refs) {
    my $expected = $refs->{$ref};
    my $value = $parser->parse($ref);
    delete $value->{id_validator};
    is_deeply $value, $expected, "Should return expected parse";
    $test_count += 1;
}

done_testing($test_count);
