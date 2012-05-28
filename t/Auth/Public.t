# Tests for ModelSEED::Auth::Public
use strict;
use warnings;
use ModelSEED::Auth::Public;
use HTTP::Request;
use Test::More;
use Test::Exception;
my $test_count = 0;
# Test initialization
{ 
    my $auth = ModelSEED::Auth::Public->new();
    ok defined($auth), "Should create object correctly";
    ok $auth->does("ModelSEED::Auth"), "Inherits Role";
    $test_count += 2;
}
{
    my $req = HTTP::Request->new();
    my $bad_req = {}; # not an HTTP::Request
    my $auth = ModelSEED::Auth::Public->new();
    dies_ok { $auth->wrap_http_request($bad_req) }
        "Passing an object that is not a request should die!";
    ok $auth->wrap_http_request($req), 
        "Good request should return true";
    $test_count += 2;
}
done_testing($test_count);
