use strict;
use warnings;
use Test::More plan => 8;
# unit tests for TestingHelpers.pm package, meta-testing ftw
use ModelSEED::TestingHelpers;
use Data::Dumper;
my $modelId = "Seed83333.1";

my $helper = ModelSEED::TestingHelpers->new();
my $debug_one = $helper->getDebugFIGMODEL();
ok defined($debug_one->config("model directory")->[0]), "getDebugFIGMODEL defines tmp model directory";
my $debug_two = $helper->newDebugFIGMODEL();
# Check that we can get a model of type $modelId
my $model_one = $debug_one->get_model($modelId);
my $model_two = $debug_two->get_model($modelId);
ok defined($model_one), "testDatabase (1) should have model $modelId";
ok defined($model_two), "testDatabase (2) should have model $modelId";
# Check that we can login with alice and bob
$debug_one->authenticate({username => "alice", password => "alice"});
$debug_two->authenticate({username => "bob", password => "bob"});
ok $debug_one->user() eq "alice", "login with alice should work";
ok $debug_two->user() eq "bob", "login with bob should work";
# Check that alice can get her model
my $alice_model_one = $debug_one->get_model($modelId.".".$debug_one->userObj()->_id());
ok defined($alice_model_one), "alice should be able to get her own copy of the model";
# Check that alice modifying her own model in one doesn't change two
my $alice_model_two = $debug_two->get_model($modelId.".".$debug_one->userObj()->_id());
$alice_model_one->ppo()->message("foo");
ok $alice_model_one->ppo()->message() eq "foo", "alice should be able to edit her own model";
ok $alice_model_two->ppo()->message() ne "foo", "different debug FM's should not interact with eachother's data";
