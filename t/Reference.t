use ModelSEED::Reference;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
my $test_count = 0;

my $refs = {
    "http://model-api.theseed.org/biochemistry/chenry/master" => {
        is_url             => 1,
        scheme             => 'http',
        authority          => 'model-api.theseed.org',
        type               => 'object',
        class              => 'ModelSEED::MS::Biochemistry',
        base               => "biochemistry",
        base_types         => ['biochemistry'],
        id                 => 'chenry/master',
        id_type            => 'alias',
        has_owner          => 1,
        owner              => 'chenry',
        alias_type         => 'biochemistry',
        alias_username     => 'chenry',
        alias_string       => 'master',
        parent_objects     => [],
        parent_collections => ["biochemistry"],
    },
    "http://model-api.theseed.org/biochemistry/550e8400-e29b-41d4-a716-446655440000"
        => {
        is_url             => 1,
        scheme             => 'http',
        authority          => 'model-api.theseed.org',
        type               => 'object',
        class              => 'ModelSEED::MS::Biochemistry',
        base               => "biochemistry",
        base_types         => ['biochemistry'],
        id                 => "550e8400-e29b-41d4-a716-446655440000",
        id_type            => 'uuid',
        parent_objects     => [],
        parent_collections => ["biochemistry"],
        },
    "http://model-api.theseed.org/biochemistry/chenry/master/reactions" => {
        is_url             => 1,
        scheme             => 'http',
        authority          => 'model-api.theseed.org',
        type               => 'collection',
        class              => "ModelSEED::MS::Reaction",
        base               => "biochemistry/chenry/master/reactions",
        base_types         => ['biochemistry', 'reactions'],
        parent_objects     => ["biochemistry/chenry/master"],
        parent_collections => ["biochemistry"],
        has_owner          => 1,
        owner              => 'chenry',
    },
    "http://model-api.theseed.org/biochemistry/chenry/master/reactions/550e8400-e29b-41d4-a716-446655440000"
        => {
        is_url             => 1,
        scheme             => 'http',
        authority          => 'model-api.theseed.org',
        has_owner          => 1,
        owner              => 'chenry',
        type           => "object",
        class          => "ModelSEED::MS::Reaction",
        base           => "biochemistry/chenry/master/reactions",
        base_types     => ['biochemistry', 'reactions'],
        id             => "550e8400-e29b-41d4-a716-446655440000",
        id_type        => 'uuid',
        parent_objects => ["biochemistry/chenry/master"],
        parent_collections =>
            ["biochemistry", "biochemistry/chenry/master/reactions"],
        },
    "http://model-api.theseed.org/biochemistry/550e8400-e29b-41d4-a716-446655440000/reactions"
        => {
        is_url             => 1,
        scheme             => 'http',
        authority          => 'model-api.theseed.org',
        type       => "collection",
        base       => "biochemistry/550e8400-e29b-41d4-a716-446655440000/reactions",
        base_types => ['biochemistry', 'reactions'],
        class      => "ModelSEED::MS::Reaction",
        parent_objects =>
            ["biochemistry/550e8400-e29b-41d4-a716-446655440000"],
        parent_collections => ["biochemistry"],
        },
    "biochemistry/chenry/master" => {
        is_url             => 0,
        type               => "object",
        id                 => "chenry/master",
        id_type            => 'alias',
        alias_type         => 'biochemistry',
        alias_username     => 'chenry',
        alias_string       => 'master',
        has_owner          => 1,
        owner              => 'chenry',
        class              => "ModelSEED::MS::Biochemistry",
        base               => "biochemistry",
        base_types         => ['biochemistry'],
        parent_objects     => [],
        parent_collections => ["biochemistry"],
    },
    "biochemistry/550e8400-e29b-41d4-a716-446655440000" => {
        is_url             => 0,
        type               => "object",
        id                 => "550e8400-e29b-41d4-a716-446655440000",
        id_type            => 'uuid',
        class              => "ModelSEED::MS::Biochemistry",
        base               => "biochemistry",
        base_types         => ['biochemistry'],
        parent_objects     => [],
        parent_collections => ["biochemistry"],
    },
    "http://model-api.theseed.org/biochemistry/chenry/master" => {
        is_url             => 1,
        scheme             => 'http',
        authority          => 'model-api.theseed.org',
        type               => "object",
        id                 => "chenry/master",
        id_type            => 'alias',
        alias_type         => 'biochemistry',
        alias_username     => 'chenry',
        alias_string       => 'master',
        class              => "ModelSEED::MS::Biochemistry",
        base               => "biochemistry",
        base_types         => ['biochemistry'],
        parent_objects     => [],
        parent_collections => ["biochemistry"],
        has_owner          => 1,
        owner              => 'chenry',
    },
    "biochemistry" => {
        is_url             => 0,
        type               => "collection",
        class              => "ModelSEED::MS::Biochemistry",
        base_types         => ['biochemistry'],
        parent_objects     => [],
        parent_collections => [],
        has_owner          => 0,
    },
    "biochemistry/chenry" => {
        is_url             => 0,
        type               => "collection",
        class              => "ModelSEED::MS::Biochemistry",
        base_types         => ['biochemistry'],
        parent_objects     => [],
        parent_collections => ['biochemistry'],
        has_owner          => 1,
        owner              => 'chenry',
    },

};

foreach my $ref (keys %$refs) {
    my $expected = $refs->{$ref};
    my $reference = ModelSEED::Reference->new({ ref => $ref });
    foreach my $key (keys %$expected) {
        is_deeply $reference->$key, $expected->{$key}, "Ref: $ref should have correct $key";
        $test_count += 1;
    }
    # test constructing new reference from parts
    TODO : {
        local $TODO =  "Need to clean up reference initialization";
        my $config = {
            base => $reference->base,
            is_url => $reference->is_url,
            type => $reference->type,
            has_owner => $reference->has_owner,
        };
        $config->{owner} = $reference->owner if($reference->has_owner);
        $config->{id} = $reference->id if(defined($reference->id));
        if($reference->is_url) {
            $config->{scheme} = $reference->scheme;
            $config->{authority} = $reference->authority;
        }
        my $secondRef = ModelSEED::Reference->new($config);
        is $secondRef->ref, $reference->ref, "Constructing ref should work for $ref";
        $test_count += 1;
    }
}

done_testing($test_count);
