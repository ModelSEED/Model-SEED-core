#===============================================================================
#
#         FILE:  FIGMODELdatabase.t
#
#  DESCRIPTION:  Testing for FIGMODELdatabase.
#       AUTHOR:  Scott Devoid (sdevoid@gmail.com) 
#      CREATED:  October 04, 2011
#===============================================================================

use strict;
use warnings;
use Data::Dumper;
use ModelSEED::FIGMODEL::FIGMODELdatabase;
use ModelSEED::FIGMODEL;
use ModelSEED::TestingHelpers;
use File::Temp qw(tempfile);
use Test::More;
use Try::Tiny;

my $helper = ModelSEED::TestingHelpers->new();
my $fm = $helper->getDebugFIGMODEL();
# test creation of database from configuration
{
    my $config = $fm->_get_FIGMODELdatabase_config();
    my $db = ModelSEED::FIGMODEL::FIGMODELdatabase->new($config, $fm);
    my $config2 = $db->config();
    ok $config == $config2, "config data should be pass by reference";
    foreach my $type (keys %{$config->{"object types"}}) {
        ok $db->is_type($type), "passed in $type within object types, but is_type not consistent";
    }
    ok $db->is_type("model"), "model should be a type that we know about";
    my $obj = $db->get_object("model", { id => "Seed83333.1"});
    ok defined($obj), "get_object on model Seed83333.1 should work";
    $obj = $db->get_object("model", { id => "foobazz"});
    ok !defined($obj), "get_object on foobazz should return undef";
    $obj = $db->get_object("model");
    ok defined($obj), "get_object with no query should return some model";
    # Testing failure for queries with bad types
    my $fail = 0;
    try {
        ok $db->is_type("sdfdsss") == 0, "shouldn't get true from is_type sdfdsss";
        $obj = $db->get_object("sdfdsss");
    } catch {
        $fail = 1;     
    };
    ok $fail == 1, "get_object on non-type should die";
}
# test locking
{
    my $config = $fm->_get_FIGMODELdatabase_config();
    my $db = ModelSEED::FIGMODEL::FIGMODELdatabase->new($config, $fm);
    sub testLocking {
        my @params = @_;
        my $lck = $db->genericLock(@params);    
        ok defined($lck), "should get lock object back".
            " from genericLock call with params: " . join(", ", @params);
        my @kids;
        foreach my $count (0 .. 2) {
            my $pid = open $kids[$count] => "-|";
            die "Failed to fork: $!" unless defined $pid;
            unless ($pid) {
                my $lck = $db->genericLock(@params);
                if(defined($lck)) {
                    print "1\n";
                }
                exit;
            }
        }
        my $lines = [];
        foreach my $fh (@kids) {
            my @l = <$fh>;
            push(@$lines, @l);
        }
        $db->genericUnlock($params[0]);
        return $lines;
    }
    my $lines = testLocking("foo");
    ok @{$lines} == 0, "Shouldn't aquire lock for default genericLock call";
    $lines = testLocking("foo", "EX",1);
    ok @{$lines} == 0, "Shouldn't aquire lock for genericLock, exclusive";
}
# test file-printing / reading
{
    my $arrayRefOut = [(0 .. 20)];
    my $config = $fm->_get_FIGMODELdatabase_config();
    my $db = ModelSEED::FIGMODEL::FIGMODELdatabase->new($config, $fm);
    my ($fh, $filename) = tempfile();
    $db->print_array_to_file($filename, $arrayRefOut);
    ok -f $filename, "should create file with print_array_to_file";
    my $count = `wc -l $filename`;
    $count =~ s/^\s+(\d+).*$/$1/;
    ok $count == 20, "should create 20 lines of file, got $count"; 
    my $arrayRefIn = $db->load_single_column_file($filename);
    ok @$arrayRefIn == @$arrayRefOut, "Should get the same number of lines in as out.";
}
# test cache tools
TODO: {
    try {
    local $TODO = "CHI does not like to cache code refs";
    my $config = $fm->_get_FIGMODELdatabase_config();
    my $db = ModelSEED::FIGMODEL::FIGMODELdatabase->new($config, $fm);
    ok defined($db->_cache()), "should be able to get the CHI cache.";
    $db->_cache()->set("foo", "bar");
    ok defined($db->_cache()->get("foo")), "by default, cache should default to RawMemory.";
    my $hash1 = $db->get_object_hash({ type => "media",
        useCache => 1, attribute => "id"});
    $config->{CacheSettings} = { driver => "RawMemory", global => 1};
    $db = ModelSEED::FIGMODEL::FIGMODELdatabase->new($config, $fm);
    $db->_cache()->set("foo", "bar");
    ok $db->_cache()->get("foo") eq "bar", "cache RawMemory should work correctly";
    my $objs = $db->get_objects("reaction", {}, 1);
    my $objs2 = $db->get_objects("media", {}, 1);
    my $objs3 = $db->get_objects("media", {}, 1);
    my $hash2 = $db->get_object_hash({ type => "media",
        useCache => 1, attribute => "id"});
    my $hash3 = $db->get_object_hash({ type => "reaction",
        parameters => {}, useCache => 1, attribute => sub { return $_[0]->id(); }});
    };
}

done_testing();
