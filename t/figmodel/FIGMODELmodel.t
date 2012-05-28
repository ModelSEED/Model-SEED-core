#
#===============================================================================
#
#         FILE:  FIGMODELmodel.t
#
#  DESCRIPTION:  Testing for FIGMODELmodel.
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  Currently implementing for regression testing prior to
#                implementing directory based models.
#       AUTHOR:  Scott Devoid (sdevoid@gmail.com)
#      CREATED:  04/27/11 16:18:35
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Data::Dumper;
use ModelSEED::FIGMODEL;
use ModelSEED::TestingHelpers;
use Try::Tiny;
use Test::More tests => 49;
use File::Temp qw(tempfile);

my $helper = ModelSEED::TestingHelpers->new();
my $fm = $helper->getDebugFIGMODEL();

# test general access routines
{
    my $public_model = $fm->get_model('Seed83333.1'); 
    ok $public_model->status() eq 2, "Model Seed83333.1 has status other than 1, complete!";
    ok $public_model->genome() eq "83333.1", "Model Seed83333.1 has genome other than 83333.1!";
    ok $public_model->owner() eq "master", "Public model Seed83333.1 has owner other than 'master'!";
    ok $public_model->rights('PUBLIC') eq 'view', "Public model Seed83333.1 does not give 'view' rights to 'PUBLIC'!";
    ok $public_model->directory() =~ m/master\/Seed83333\.1\/\d+\//, "public model doesn't have directory that looks like /master/Seed83333.1/\\d+/!";
	#Test SBML file printing
	$public_model->PrintSBMLFile();
    my $expectedSBML = $public_model->directory().$public_model->id().".xml";
	ok -e $expectedSBML, "SBML file failed to print for model Seed83333.1 at $expectedSBML";
}
# test general access routines on private-model
{
    my $alice_id = $fm->database()->get_object("user", { login => "alice"})->_id();
    my $model = "Seed83333.1.".$alice_id;
    my $private_model = $fm->get_model($model);
    ok !defined($private_model), "model $model is private, should have to login as alice to see it!";
}
# testing general access to non-canonical model
{
    my $oldest = $fm->get_model('Seed83333.1.v0'); 
    ok $oldest->id() eq 'Seed83333.1', "non-canonical model still returns canonical id, returned " . $oldest->id();
    ok $oldest->genome() eq "83333.1", "Model Seed83333.1 has genome other than 83333.1!";
    ok $oldest->directory() =~ m/master\/Seed83333\.1\/0\//, "old model-version points to correct directory";
}
# testing that a model's figmodel, database, etc. are not shared with other models
{
    my $b = $fm->get_model('Seed83333.1');
    my $a = $fm->get_model('Seed83333.1.v0');
    ok $a->figmodel() ne $b->figmodel(), "Two models should not have the same figmodel() object";
    ok $a->figmodel()->database() ne $b->figmodel()->database(), "Two models should not have the same database() object";
    ok $a->figmodel() ne $fm, "a model should have it's own figmodel() object, not it's initializer";
    ok $a->figmodel()->database() ne $fm->database(), "a model should have it's own database() object, not it's initializer's";
    my $file_type = $a->figmodel()->database()->get_config("rxnmdl")->{type}->[0];
    my $wanted_type;
    if ($a->version() != $a->ppo_version() ) {
        $wanted_type = "FIGMODELTable";
    } else {
        $wanted_type = "PPO";
    }
    ok $file_type eq $wanted_type, "type for rxnmdl should be $wanted_type, got $file_type";
    my $ppo_type = $b->figmodel()->database()->get_config("rxnmdl")->{type}->[0];
    ok $ppo_type eq "PPO", "type for 'current model' rxnmdl should be PPO!, got $ppo_type";
}
# testing that fm->database() isn't corrupted at this point 
{
    my $fm_rxnmdl_type = $fm->database()->get_config("rxnmdl")->{type}->[0];
    ok $fm_rxnmdl_type eq "PPO", "type for figmodel rxnmdl should be PPO, got $fm_rxnmdl_type";
    my $fm_compound_type = $fm->database()->get_config("compound")->{type}->[0];
    ok $fm_compound_type eq "PPO", "type for figmodel compound should be PPO, got $fm_compound_type";
    my $fm_reaction_type = $fm->database()->get_config("compound")->{type}->[0];
    ok $fm_reaction_type eq "PPO", "type for figmodel reaction should be PPO, got $fm_reaction_type";
}

# testing versioning
{
    my $canonical = $fm->get_model('Seed83333.1'); 
    ok $canonical->version() == $canonical->ppo_version(), "model called without version number returns canonical version". $canonical->version();
    my $oldest = $fm->get_model('Seed83333.1.v0'); 
    ok defined($oldest), "oldest model version Seed83333.1.v0 exists";
    #ok $oldest->version() != $oldest->ppo_version(), "ppo_version() and version() disagree for old model";
    ok !$oldest->isEditable(), "shouldn't be able to edit public model";
}
# testing attempts to version-modify model as PUBLIC
{
    my $not_owned = $fm->get_model('Seed83333.1'); 
    my ($fh, $filename) = tempfile();
    close($fh);
    my ($failOne, $failTwo, $failThree) = (0,0,0);
    try {
        $not_owned->flatten($filename);
    } catch {
        $failOne = 1;
    };
    ok $failOne == 1, "flatten() on public model when not logged in should fail";
    my $version = $not_owned->version();    
    try { 
        $not_owned->increment();
    };
    ok $version == $not_owned->version(), "increment() on public model when not logged in should fail.";
    try {
        $not_owned->restore(0,$not_owned->version())
    } catch {
        $failThree = 1;
    };
    ok $failThree==1, "restore() on non-owned model should fail.";
}
# PRIVATE MODEL TESTS
{
    # testing getting private model (user: alice, model: Seed83333.1.1)
    $fm->authenticate({ username => "alice", password => "alice"});
    ok $fm->user() eq "alice", "a bit of meta-testing: we did log in correct?";
    my $private_model = $fm->get_model('Seed83333.1.1');
    ok defined($private_model), "should actually get model Seed83333.1.1";
    ok $private_model->version() == $private_model->ppo_version(), "we should get the cannonical version of Seed83333.1.1, got " . $private_model->version();
}

# VERSIONING TESTS:
{
    # TESTING PORCELAIN functions: checkpoint() and revert(i)
    # setup... 
    my $fm = $helper->newDebugFIGMODEL();
    $fm->authenticate({ username => "alice", password => "alice"});
    my $mdl = $fm->get_model("Seed83333.1.1");
    my $mdl_db = $mdl->figmodel()->database();
     
    ok defined($mdl), "should actually get model Seed83333.1.1";
    ok $mdl->isEditable(), "should be able to edit Seed83333.1.1";

    # testing checkpoint()
    my $curr_version = $mdl->version();
    my $curr_dir = $mdl->directory();
    $mdl->checkpoint();
    ok $mdl->directory() ne $curr_dir, "checkpoint should change the current directory, got: ".$mdl->directory();
    ok $mdl->version() == $curr_version + 1, "checkpoint should increment current version, got: ".$mdl->version()." wanted: $curr_version";
    my $rxnmdl_file = $curr_dir."rxnmdl.txt";
    ok -f $rxnmdl_file, "checkpoint should create an rxnmdl file at $rxnmdl_file";

    my $count = `wc -l $rxnmdl_file`;
    $count =~ s/^\s+(\d+)\s.*/$1/;
    $count = $count - 1 if($count > 0);
    my $rxns_count = $mdl->figmodel()->database()->get_objects("rxnmdl", { MODEL => $mdl->id() });
    ok $count == scalar(@$rxns_count), "checkpoint should save a copy of the currnet rxnmdls, got: $count, expected: " . scalar(@$rxns_count);
    # FIXME TestData does not get rxnmdls because they're not in ModelDB

    # testing restore()
    for(my $i=0; $i<@$rxns_count; $i++) { # delete some rxnmls
        last if($i == 3); # just delete the first 3
        $rxns_count->[$i]->delete();
    }
    $mdl->revert($curr_version);    
    ok $mdl->version() == $curr_version + 1, "revert(i) should retain the current version, not adopt i or something else";
    my $new_rxns_count = $mdl->figmodel()->database()->get_objects("rxnmdl", { MODEL => $mdl->id() });
    ok scalar(@$new_rxns_count) == $count, "revert(i) should result in the same number of rxnmdls as i/rxnmdl.txt; got: ".
        scalar(@$new_rxns_count) . ", wanted: $count";
    # FIXME TestData does not get rxnmdls because they're not in ModelDB
}
# TEST plumbing commands: flatten(), increment(), restore()
{
    # setup...
    my $fm = $helper->newDebugFIGMODEL();
    $fm->authenticate({ username => "alice", password => "alice"});
    my $private_model = $fm->get_model('Seed83333.1.1');
    my $private_model_db = $private_model->figmodel()->database();
    
    # confirm setup..
    ok defined($private_model), "should actually get model Seed83333.1.1";
    ok $private_model->version() == $private_model->ppo_version(),
        "we should get the cannonical version of Seed83333.1.1, got " . $private_model->version();
    ok $private_model->isEditable(), "should be able to edit Seed83333.1.1";

    # testing flatten()
    my ($fh, $filename) = tempfile();
    close($fh);
    my $rxns = $private_model_db->get_objects("rxnmdl", { MODEL => $private_model->id() });
    $private_model->flatten($filename);
    ok -f $filename, "flatten() should actually result in a file existing at: $filename";
    my $count = `wc -l $filename`;
    $count =~ s/^\s+(\d+)\s.*/$1/;
    $count = $count - 1 if($count > 0);
    ok $count == scalar(@$rxns),
        "flatten() should contain the right number of".
        " rxnmdl entries: has $count, want " . scalar(@$rxns);
    # testing increment
    my $version = $private_model->version();
    my $dir =  $private_model->directory();
    $private_model->increment();
    ok $private_model->version() eq $version + 1, "increment() should change model version.";
    ok $dir ne $private_model->version(),
        "increment() should change the model directory, got: " . $private_model->directory();

    # testing restore()
    for(my $i=0; $i<@$rxns; $i++) {
        last if($i == 3); # just delete the first 3
        $rxns->[$i]->delete();
    }
    $rxns = $private_model_db->get_objects("rxnmdl", { MODEL => $private_model->id() });
    $private_model->restore("Seed83333.1.1.v0", 1);
    my $rxnmdls = $private_model_db->get_objects("rxnmdl", { MODEL => $private_model->id() }); 
    ok scalar(@$rxnmdls) == $count, "restore() should return model to original state, got: ".scalar(@$rxnmdls)." wanted: ".$count;
    ok defined($private_model->ppo()), "restore() should provide ppo object";
    ok defined($private_model_db->get_object("model", { id => $private_model->id() })),
        "restore() should result in a model row existing in the database";
}

#### Testing copyModel
{
    my $fm = $helper->newDebugFIGMODEL();
    $fm->authenticate({ username => "alice", password => "alice"});
    my $model_orig = $fm->get_model('Seed83333.1.1');
    ok defined($model_orig), "should be able to get model Seed83333.1.1 as alice";
#    my $model_copy = $model_orig->copyModel({ owner => "bob" });
#    ok defined($model_copy), "should get model copy as alice, model successfully copied";
#    my $model_copy_id = $model_copy->id();
}
