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
use strict;
use warnings;
use ModelSEED::Config;
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
    my $c = ModelSEED::Config->new({filename => $temp_cfg_file });
    ok defined($c), "Should create class instance";
    my $j = JSON->new->utf8;
    my $data = $j->decode($TESTINI);
    is_deeply($c->config, $data, "JSON should go in correctly");

    $testCount += 2;
}


done_testing($testCount);
