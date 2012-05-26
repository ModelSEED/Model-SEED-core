# Tests for ModelSEED::Auth::Factory
use ModelSEED::Auth::Factory;
use ModelSEED::Auth::Basic;
use ModelSEED::Auth::Public;
use ModelSEED::Configuration;
use File::Temp qw(tempfile);
use HTTP::Request;
use HTTP::Headers;
use Try::Tiny;
use Module::Load;
use Test::More;

my $test_count = 0;

{
    # Test initialization
    my $factory = ModelSEED::Auth::Factory->new();
    ok defined($factory), "Should create class instance";
    $test_count += 1;

    # Test authorization with ref object, Basic
    {
        my $basic_input = ModelSEED::Auth::Basic->new(
            username => "alice",
            password => "password123"
        );
        my $req = HTTP::Request->new();
        $basic_input->wrap_http_request($req);
        my $basic_output = $factory->from_http_request($req);
        ok defined($basic_output), "Should get object back from from_http_request";
        ok $basic_output->isa("ModelSEED::Auth::Basic"), "Should get a Auth::Basic object";
        is $basic_output->username, $basic_input->username, "Should get round-trip integrity, username";
        is $basic_output->password, $basic_input->password, "Should get round-trip integrity, password";
        $test_count += 4;
    }
    #  Test authorization with ref object, Public
    { 
        my $public_input = ModelSEED::Auth::Public->new();
        my $req = HTTP::Request->new();
        $public_input->wrap_http_request($req);
        my $public_output = $factory->from_http_request($req);
        ok defined($public_output), "Should get object back from from_http_request";
        ok $public_output->isa("ModelSEED::Auth::Public"), "Should get a Auth::Public object";
        is $public_output->username, $public_input->username, "Should get round-trip integrity, username";
        $test_count += 3;
    }
    
    # Try to load Dancer::Request
    my $loaded_dancer = 0;
    try {
        load Dancer::Request;
        $loaded_dancer = 1;
    };
    my $dancer_tests = 7;
    SKIP : {
        skip "Dancer not installed", $dancer_tests unless($loaded_dancer); 
        {
            my $basic_input = ModelSEED::Auth::Basic->new(
                username => "alice",
                password => "password123"
            );
            my $req;
            {
                my $http_req = HTTP::Request->new();
                $basic_input->wrap_http_request($http_req);
                my $headers = HTTP::Headers->new;
                $headers->header( "Authorization" => $http_req->header("Authorization"));
                $req = Dancer::Request->new_for_request('GET' => 'http://google.com', undef, undef, $headers);
            }
            my $basic_output = $factory->from_dancer_request($req);
            ok defined($basic_output), "Should get object back from from_http_request";
            ok $basic_output->isa("ModelSEED::Auth::Basic"), "Should get a Auth::Basic object";
            is $basic_output->username, $basic_input->username, "Should get round-trip integrity, username";
            is $basic_output->password, $basic_input->password, "Should get round-trip integrity, password";
        }
        #  Test authorization with ref object, Public
        { 
            my $public_input = ModelSEED::Auth::Public->new();
            my $req;
            {
                my $http_req = HTTP::Request->new();
                $public_input->wrap_http_request($http_req);
                my $headers = HTTP::Headers->new;
                $headers->header( "Authorization" => $http_req->header("Authorization"));
                $req = Dancer::Request->new_for_request('GET' => 'http://google.com', undef, undef, $headers);
            }
            my $public_output = $factory->from_dancer_request($req);
            ok defined($public_output), "Should get object back from from_http_request";
            ok $public_output->isa("ModelSEED::Auth::Public"), "Should get a Auth::Public object";
            is $public_output->username, $public_input->username, "Should get round-trip integrity, username";
        }
    };
    $test_count += $dancer_tests;
}

# Test from_config : empty
{ 
    my ($fh, $filename) = tempfile();
    $ENV{MODELSEED_CONF} = $filename;
    print $fh "{}";
    close($fh);
    my $factory = ModelSEED::Auth::Factory->new();
    my $auth = $factory->from_config();
    ok defined($auth), "Should get auth back from from_config, empty";
    ok $auth->isa("ModelSEED::Auth::Public"), "Should get public from empty config";

    $test_count += 2;
}

# Test from_config : populated
{ 
    my ($fh, $filename) = tempfile();
    $ENV{MODELSEED_CONF} = $filename;
    print $fh '{ "login" : { "username" : "alice", "password" : "password" }}';
    close($fh);
    my $factory = ModelSEED::Auth::Factory->new();
    my $auth = $factory->from_config();
    ok defined($auth), "Should get auth back from from_config, empty";
    ok $auth->isa("ModelSEED::Auth::Basic"), "Should get public from empty config";
    is $auth->username, "alice", "Should get correct user";
    is $auth->password, "password", "Should get correct pass";
    
    $test_count += 4;
}

done_testing($test_count);
