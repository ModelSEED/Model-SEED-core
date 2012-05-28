# Tests for ModelSEED::Auth::Basic
use strict;
use warnings;
use ModelSEED::Auth::Basic;
use HTTP::Request;
use Test::More;
use Test::Exception;
my $test_count = 0;
# Test initialization
{ 
    my $auth = ModelSEED::Auth::Basic->new(
        username => "alice",
        password => "password"
    );
    ok defined($auth), "Should create object correctly";
    dies_ok {
        ModelSEED::Auth::Basic->new();
    } "Should die if no username or password is passed";
    dies_ok {
        ModelSEED::Auth::Basic->new(username => "foo");
    } "Should die if no password is passed";
    dies_ok {
        ModelSEED::Auth::Basic->new(password => "foo");
    } "Should die if no username is passed";

    my $auth2 = ModelSEED::Auth::Basic->new({
        username => "alice",
        password => "password"
    });
    ok defined($auth2), "Should create object correctly with hash";
    ok $auth->does("ModelSEED::Auth"), "Inherits Role";
    $test_count += 6;
}
{
    my $req = HTTP::Request->new();
    my $bad_req = {}; # not an HTTP::Request
    my $auth = ModelSEED::Auth::Basic->new({
        username => "alice",
        password => "password",
    });
    dies_ok { $auth->wrap_http_request($bad_req) }
        "Passing an object that is not a request should die!";
    ok $auth->wrap_http_request($req), 
        "Good request should return true";
    ok defined($req->header("Authorization")),
        "Request object should have Athorization header now";

    $test_count += 3;
}
done_testing($test_count);
