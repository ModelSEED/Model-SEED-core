use strict;
use warnings;
use ModelSEED::Configuration;
use File::Temp qw(tempfile);
use JSON;
use Test::More;
my $testCount = 0;

my ($fh, $TMPDB) = tempfile();
my $TESTINI = <<INI;
{
    "auth" : {
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

    my $d = ModelSEED::Configuration->instance;
    is_deeply($d, $c, "Should be singleton class");

    $testCount += 3;
}


done_testing($testCount);
