#
#===============================================================================
#
#         FILE: Config.t
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 04/04/2012 17:13:39
#     REVISION: ---
#===============================================================================
use Data::Dumper;
use strict;
use warnings;
use ModelSEED::Config;
use File::Temp qw(tempfile);
use Test::More;
my $testCount = 0;

my ($fh, $TMPDB) = tempfile();

my $TESTINI = <<INI;
[auth]
username=alice
password=alice's password

[stores]
local=type:file;filename:$TMPDB

INI


{
    my ($fh, $temp_cfg_file) = tempfile();
    print $fh $TESTINI;
    close($fh);

    # test initialization
    my $c = ModelSEED::Config->new({filename => $temp_cfg_file });
    ok defined($c), "Should create class instance";

    # basic get and getSection
    is($c->get("auth", "username"), "alice", "Basic get should work");
    my $section = {username => "alice", password => "alice's password"};
    is_deeply $c->getSection("auth"), $section, "getSection should work";

    # basic set
    $c->set("auth", "username", "bob");
    is($c->get("auth", "username"), "bob", "Testing basic set operation");

    # basic setSection
    $section = { username => "bob", password => "bob's password" };
    is_deeply $c->setSection("auth", $section), $section, "setSection should work";

    # advanced on single entry
    is $c->set("auth", "token", "ticket"), "ticket", "Setting new attribute should work";
    is $c->get("auth", "token"), "ticket", "Getting newly set attribute should work";

    # advanced setSection (new section), deleting
    $section = { animal => 'cow', food => 'grass' };
    is_deeply $c->setSection("farm", $section), $section, "new section should set";
    is $c->setSection("farm", undef), undef, "deleting section should return undef";
    is $c->getSection("farm"), undef, "deleted section should be gone";

    # test advanced attributes
    is_deeply $c->get("stores", "local"),
              {type => "file", filename => $TMPDB}, 
              "Getting a local store should return a hash";
    my $update = {type => "file", filename => "foo"};
    is_deeply $c->set("stores", "local", $update), $update,
        "Update to local store should work";
    is_deeply $c->set("stores", "local", "type:file;filename:foo"), $update,
        "Update with string should work";
    $testCount += 13;
}


done_testing($testCount);
