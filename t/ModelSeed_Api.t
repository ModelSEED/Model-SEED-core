#!/usr/bin/env perl
#
use Test::More;
use ModelSEED::Api;
use ModelSEED::ObjectManager;

my $om = ModelSEED::ObjectManager->new({
    database => '/Users/devoid/Desktop/Core/test.db',
    driver => 'sqlite',
});
my $api = ModelSEED::Api->new({om => $om, url_root => 'http://test.com/'});

my $roots = [ 'http://test.com/', 'http://test.com:3000/',
              'http://test.com', 'http://test.com:3000',
            ];
my $good_refs;
my $uuids;
foreach my $root (@$roots) {
    $api->url_root($root);
    $root =~ s/\/$//;
    $uuids = ["550e8400-e29b-41d4-a716-446655440000",
                "DBB3B96A-3D63-11E1-94F6-C43F3D9902C7"];
    foreach my $uuid (@$uuids) {
        $good_refs = {
        "$root/biochem" => ['biochem', [undef, undef, undef], undef, undef],
        "$root/biochem/" => ['biochem', [undef, undef, undef], undef, undef],
        "$root/biochem/$uuid" =>
            ['biochem', [$uuid, undef, undef], undef, undef],
        "$root/biochem/$uuid/reaction" =>
            ['biochem', [$uuid, undef, undef], "reaction", undef],
        "$root/biochem/$uuid/reaction/" =>
            ['biochem', [$uuid, undef, undef], "reaction", undef],
        "$root/biochem/$uuid/reaction/$uuid" =>
            ['biochem', [$uuid, undef, undef], "reaction", $uuid],
        "$root/biochem/alice/master" =>
            ['biochem', [undef, "alice", "master"], undef, undef],
        "$root/biochem/alice/master/" =>
            ['biochem', [undef, "alice", "master"], undef, undef],
        "$root/biochem/alice/master/reaction" =>
            ['biochem', [undef, "alice", "master"], "reaction", undef],
        "$root/biochem/alice/master/reaction/" =>
            ['biochem', [undef, "alice", "master"], "reaction", undef],
        "$root/biochem/alice/master/reaction/$uuid" =>
            ['biochem', [undef, "alice", "master"], "reaction", $uuid],
        };
        foreach my $url (keys %$good_refs) {
            my $struct = [$api->parseReference($url)];
            my $expected = $good_refs->{$url};
            is_deeply $struct, $expected, "Failed to correctly parse $url";
        }
    }
}

done_testing( scalar(@$uuids) * scalar(@$roots) * scalar(keys %$good_refs) );






    
     
