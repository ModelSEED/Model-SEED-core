use strict;
use warnings;
use Test::More qw(no_plan);
# unit tests for TestingHelpers.pm package, meta-testing ftw
use ModelSEED::TestingHelpers;

my $helper = ModelSEED::TestingHelpers->new();
my $debug_fm = $helper->getDebugFIGMODEL();
ok $debug_fm->config("Database version")->[0] eq 'DevModelDB', "getDebugFIGMODEL is set to DevModelDB";
ok defined($debug_fm->config("model directory")->[0]), "getDebugFIGMODEL defines tmp model directory";

my $prod_fm = $helper->getProductionFIGMODEL();
ok $prod_fm->config("Database version")->[0] eq 'ModelDB', "getProductionFIGMODEL is set to ModelDB";
my $prod_model = $prod_fm->get_model("Seed83332.1");
$helper->copyProdModelState("Seed83332.1");
my $debug_model = $debug_fm->get_model("Seed83332.1");

ok $prod_model->id() eq $debug_model->id(), "copyProdModelState produces same model id";
ok $prod_model->version() eq $debug_model->version(), "copyProdModelState preserves model version";
ok $prod_model->directory() ne $debug_model->directory(), "copyProdModelState produces different directory() listing";
# check that the directory copy worked correctly:
my $prod_dir_count = 0;
my $debug_dir_count = 0;
{
    opendir(my $dir, $prod_model->directory()) || die($@);
    my $file;
    $file =~ m/^\.\.?$/ or $prod_dir_count++ while($file = readdir($dir));
}
{
    opendir(my $dir, $debug_model->directory()) || die($@);
    my $file;
    $file =~ m/^\.\.?$/ or $debug_dir_count++ while($file = readdir($dir));
}
ok $prod_dir_count == $debug_dir_count, "copyProdModelState correctly dircopy's the model's snapshots";
# check that we're not modifying the same data
my $prod_model_msg = $prod_model->message();
my $dev_model_msg = $debug_model->message("foo");
ok $prod_model_msg eq $prod_model->message(), "edits to dev model don't affect prod model";

# check that copyProdModelState on non-existant model in Production works as expected
# i.e. if the model exists in development, it should be wiped out. Otherwise nothing happens.
{
    # get a model that doesn't exist in production
    my $id = "asodnfo2nsdlfs";
    my $prod_mdl = $prod_fm->get_model($id);
    ok !defined($prod_mdl), "model '$id' should not exist in production";
    $helper->copyProdModelState($id);
    my $debug_mdl = $debug_fm->get_model($id);
    ok !defined($debug_mdl), "model '$id' should not become defined in development";
    my $dev_mdl_dir = $debug_fm->config("model directory")->[0] . "master/$id";
    File::Path::make_path $dev_mdl_dir;
    $helper->copyProdModelState($id);
    ok !-d $dev_mdl_dir, "copyProdModelState on non-existant model should remove directory $dev_mdl_dir!";
}
    

