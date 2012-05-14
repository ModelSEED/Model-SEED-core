use strict;
use warnings;
use ModelSEED::Configuration;
use File::Temp qw(tempfile);
use JSON;
use Test::More;
use Test::Exception;
my $testCount = 0;

my ($fh, $TMPDB) = tempfile();
my $TESTINI = <<INI;
{
    "login" : {
        "username" : "alice",
        "password" : "alice's password"
    },
    "stores" : [
        {
            "name" : "local",
            "class" : "ModelSEED::Database::FileDB",
            "filename" : "$TMPDB"
        }
    ]
}
INI

{
    my ($fh, $temp_cfg_file) = tempfile();
    print $fh $TESTINI;
    close($fh);

    # test initialization
    my $c = ModelSEED::Configuration->new({filename => $temp_cfg_file });
    ok defined($c), "Should create class instance";
    my $j = JSON->new->utf8;
    my $data = $j->decode($TESTINI);
    is_deeply($c->config, $data, "JSON should go in correctly");

    # test singleton interface
    TODO: {
        local $TODO = "Singleton destructor not working";
        my $d = ModelSEED::Configuration->instance;
        is_deeply($d, $c, "Should be singleton class");
    };

    # test save
    ok $c->save(), "Save should return correctly";
    # test save actually updates
    {
        $c->config->{login}->{username} = "bob";
        $c->save();
        my $d = ModelSEED::Configuration->new({filename => $temp_cfg_file});
        is_deeply($d->config, $c->config, "Should contain same info");
        is $d->config->{login}->{username}, "bob", "New instance should get data";
    }
    # test exception on invalid data being saved
    {
        $c->config->{model} = ["an", "array"];
        dies_ok( sub { $c->save() }, "Should die when trying to save invalid data");
    }

    $testCount += 7;
}


done_testing($testCount);
