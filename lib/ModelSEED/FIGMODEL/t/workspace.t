use Test::More qw(no_plan);
use File::Temp;
use File::Path;
use ModelSEED::globals;
use ModelSEED::FIGMODEL::workspace;
use Try::Tiny;

#Workspace will soon be completely severed from FIGMODEL, as it is an interface component, not a FIGMODEL component
#Thus, I removed testing helper and FIGMODEL from this test.
my $tempWorkspaceDriectory = File::Temp::tempdir()."/";
my $tempBinaryDirectory = File::Temp::tempdir()."/";
my $ws = ModelSEED::FIGMODEL::workspace->new({owner => 'alice', root => $tempWorkspaceDriectory,binDirectory => $tempBinaryDirectory});
ok $ws->id eq "default", "Default workspace id is 'default'";
ok $ws->directory eq $tempWorkspaceDriectory."alice/default/", 
    "Workspace should be at ".$tempWorkspaceDriectory."alice/default/, got ".$ws->directory;
ok -e $tempBinaryDirectory."ms-goworkspace","Workspace should print a binary file that changes to the workspace directory.";
my $binary = ModelSEED::globals::LOADFILE($tempBinaryDirectory."ms-goworkspace");
ok $binary->[0] eq "cd ".$ws->directory(),"'ms-goworkspace' binary should contain the command 'cd ".$ws->directory()."'. Got ".$binary->[0];
ok -e $tempWorkspaceDriectory."alice/current.txt","Workspace should print the file '".$tempWorkspaceDriectory."alice/current.txt"."' containing the current workspace ID.";
my $wsenv = ModelSEED::globals::LOADFILE($tempWorkspaceDriectory."alice/current.txt");
ok $wsenv->[0] eq "default","'current.txt' file should contain the id 'default'. Got ".$wsenv->[0];
system('touch '.$ws->directory().'foo.txt');
my $ws2 = ModelSEED::FIGMODEL::workspace->new({
	owner => 'alice',
	root => $tempWorkspaceDriectory,
	binDirectory => $tempBinaryDirectory,
	copy => $ws,
	id => 'two'
});
$wsenv = ModelSEED::globals::LOADFILE($tempWorkspaceDriectory."alice/current.txt");
ok $wsenv->[0] eq "two","'current.txt' file should contain the id 'two'. Got ".$wsenv->[0];
ok -f $ws2->directory."foo.txt", "copy initialization should work";
ok $ws2->id eq 'two', "should be able to set different workspace id";
$ws2->clear();
ok !-f $ws2->directory."foo.txt", "clear() should work";
ok -f $ws->directory."foo.txt", "clear() on other workspace should not affect me";

my $caught = 0;
try {
    my $ws3 = ModelSEED::FIGMODEL::workspace->new(
        { owner => 'alice', root => $root,binDirectory => $tempBinaryDirectory, id => "//bad/stuf/here"});
} catch {
    $caught = 1;
};
ok $caught, "should fail when id is bad";
File::Path::rmtree($tempWorkspaceDriectory);
File::Path::rmtree($tempBinaryDirectory);