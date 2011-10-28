use Test::More qw(no_plan);
use ModelSEED::TestingHelpers;
use ModelSEED::FIGMODEL::workspace;
use Try::Tiny;

my $helper = ModelSEED::TestingHelpers->new();
my $fm = $helper->getDebugFIGMODEL();
my $pfm = $helper->getProductionFIGMODEL();
my $root = $fm->config("Workspace directory")->[0];
my $proot = $pfm->config("Workspace directory")->[0];
ok $root ne $proot, "Workspace directory for testing should not be the same as the real workspace directory!";
my $ws = ModelSEED::FIGMODEL::workspace->new({owner => 'alice', root => $root});
ok $ws->id eq "default", "Default workspace id is 'default'";
ok $ws->directory eq $root."alice/default/", 
    "Workspace should be at ${root}alice/default/, got ".$ws->directory;
system('touch '.$ws->directory().'foo.txt');
my $ws2 = ModelSEED::FIGMODEL::workspace->new(
    {owner => 'alice', root => $root, copy => $ws, id => 'two'});
ok -f $ws2->directory."foo.txt", "copy initialization should work";
ok $ws2->id eq 'two', "should be able to set different workspace id";
$ws2->clear();
ok !-f $ws2->directory."foo.txt", "clear() should work";
ok -f $ws->directory."foo.txt", "clear() on other workspace should not affect me";
my $caught = 0;
try {
    my $ws3 = ModelSEED::FIGMODEL::workspace->new(
        { owner => 'alice', root => $root, id => "//bad/stuf/here"});
} catch {
    $caught = 1;
};
ok $caught, "should fail when id is bad";
    
