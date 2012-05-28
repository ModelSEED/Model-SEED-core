use strict;
use warnings;
use lib 'lib';
use Test::More;
use Module::Pluggable search_path => ['ModelSEED'];

# Test for compliation errors in all plugins under ModelSEED.
require_ok($_) for __PACKAGE__->plugins;
done_testing(scalar(__PACKAGE__->plugins));
