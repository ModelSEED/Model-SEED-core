#
#===============================================================================
#
#         FILE:  TestingHelpers.pm
#
#  DESCRIPTION:  A set of helper routines for building unit and integration tests
#                over the ModelSEED codebase. For example, setting up a development
#                or debug configuration for FIGMODEL, making sure the DevModelDB
#                is used in place of ModelDB (production) and doing things like
#                copying a whole model history over into a debug setting.
#
#       AUTHOR:  Scott Devoid (sdevoid@gmail.com)
#      VERSION:  1.0
#      CREATED:  06/09/11 12:37:19
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use File::Copy::Recursive qw(dircopy);
use File::Path qw(make_path remove_tree);
use File::Temp;
use ModelSEED::FIGMODEL;
use Data::Dumper;

package ModelSEED::TestingHelpers;

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

=head3 getDebugFIGMODEL

Returns a debug version of FIGMODEL with
proper configuration setup. Accepts a hash
ref of arguments that you would like to pass
into the FIGMODEL constructor. If you would
like to modify the default debug config,
call getDebugFIGMODELConfig()

=cut
sub getDebugFIGMODEL {
    my ($self, $args) = @_;
    if(not defined($self->{_figmodel})) {
        $self->{_figmodel} = $self->newDebugFIGMODEL();
    }
    return $self->{_figmodel};
}

sub newDebugFIGMODEL { 
    my ($self, $args) = @_;
    unless(defined($args)) {
        $args = $self->getDebugFIGMODELConfig();
    }
    return ModelSEED::FIGMODEL->new($args);
}

sub getDebugFIGMODELConfig {
    my ($self) = @_;
    my $prodFM = $self->getProductionFIGMODEL();
    my $testConfig = $self->getTestConfig();
    my $configs = [];
    push(@$configs, @{$prodFM->{_configSettings}});
    push(@$configs, $testConfig);
    return { configFiles => $configs }; 
}

sub copyProdModelState {
    my ($self, $id) = @_;
    $self->getDebugFIGMODEL()->authenticate({ username => $ENV{SAS_USER}, password => $ENV{SAS_PASSWORD} });
    $self->getProductionFIGMODEL()->authenticate({ username => $ENV{SAS_USER}, password => $ENV{SAS_PASSWORD} });
    my $model = $self->{_prodFIGMODEL}->get_model($id);
    $id = $model->id() if(defined($model));
    my $default_owner = 'master';
    if($id =~ /\d+\.\d+\.(\d+)$/) {
        $default_owner = $1; 
        my $tmp = $self->getDebugFIGMODEL()->database()->get_object("user", { _id => $default_owner });
        $default_owner = $tmp->login() if defined($tmp); 
    }
    my $owner = defined($model) ? $model->owner() : $default_owner;
    my $dir = defined($model) ? $model->directory() : undef;
    # remove old model directory structure
    my $path = $self->getDebugFIGMODEL()->config("model directory")->[0];
    $path .= $owner ."/". $id . '/';
    File::Path::remove_tree $path if(-d $path);
    # copy the whole model directory structure
    if(defined($model) && -d $dir) {
        $dir =~ s/\d+\/$//; # remove trailing version numbers
        File::Path::make_path($path);
        File::Copy::Recursive::dircopy($dir, $path);
    }
    
    my $db = $self->getDebugFIGMODEL()->database();
    # delete old ppo info in Dev DB
    {
        my $old_rxn_mdls = $db->get_objects("rxnmdl", { MODEL => $id });
        foreach my $rxnmdl (@$old_rxn_mdls) {
            $rxnmdl->delete();
        }
        my $obj = $db->get_object("model", { id => $id });
        $obj->delete() if defined($obj);
        my $old_versions = $db->get_objects("model_version", { canonicalID => $id });
        foreach my $version (@$old_versions) {
            $version->delete();
        }
    }
    # copy over rxnmdl from production PPO 
    {
        my $prod_db = $self->{_prodFIGMODEL}->database();
        my $rxn_mdls = $prod_db->get_objects("rxnmdl", { MODEL => $id });
        foreach my $rxnmdl (@$rxn_mdls) {
            my $hash = { map { $_ => $rxnmdl->$_() } keys %{$rxnmdl->attributes()} };
            $db->create_object("rxnmdl", $hash);
        }
        # and copy over model row
        my $prod_model = $prod_db->get_object("model", { id => $id });
        if(defined($prod_model)) {
            my $model_hash = { map { $_ => $prod_model->$_() } keys %{$prod_model->attributes()} }; 
            my $obj = $db->create_object("model", $model_hash);
        }
        # and copy over all model version entries
        my $prod_model_versions = $prod_db->get_objects("model_version", { canonicalID => $id });
        foreach my $version (@$prod_model_versions) {
            my $hash = { map { $_ => $version->$_() } keys %{$version->attributes()} };
            $db->create_object("model_version", $hash);
        }
    }
    $self->{_prodFIGMODEL} = undef;    
    $self->{_figmodel} = undef;    
    return;
}

sub getProductionFIGMODEL {
    my ($self, $args) = @_;
    if(not defined($self->{_prodFIGMODEL})) {
        $self->{_prodFIGMODEL} = ModelSEED::FIGMODEL->new();
    }
    return $self->{_prodFIGMODEL};
}

=head2 getTestConfig

Produces a clean test configuration containing data for
running test scripts. If the test configuration data doesn't
already exist (at ${"database root directory"}/TestData/
this function automatically downloads the data from the server.

This test data is then copied to temporary directories and
the configuration files are generated pointing to that temporary
location. In this way each call to getTestConfig will produce
a clean dataset.

Returns a hash of configuration data to be passed to a FIGMODEL
using the FIGMODEL->new({ configFiles => [hash] }); argument.

=head3 Data in Test Database

Currently we produce:
- A ModelDB database with default data plus
- Two users "alice" and "bob"
- Two copies of the "Seed83333.1" model owned by
  master and "alice"

=cut
sub getTestConfig {
    my ($self, $args) = @_;
    my $rtv = {};
    my $prod = $self->getProductionFIGMODEL();
    my $TestDbURL = "http://bioseed.mcs.anl.gov/~devoid/TestDB.tgz";
    my $dataDir = $prod->config('database root directory')->[0]; 
    if ( !-d $dataDir ) {
        ModelSEED::globals::ERROR("database root directory not found at $dataDir\n");
    }
    $dataDir =~ s/\/$//;
    # Ideally we have a copy of all of the test data already
    # extracted from TestDB.tgz, but if not build it now
    my $TestDataDir = "$dataDir/TestData";
    if ( !-d $TestDataDir ) {
        # If we don't have the database try to download it
        # Fail if we are still unable to get the database.
        if ( !-f "$dataDir/TestDB.tgz") {
            system("curl $TestDbURL 2> /dev/null > $dataDir/TestDB.tgz");#Note, this does not work in windows...
            if (!-f "$dataDir/TestDB.tgz") {
                ModelSEED::globals::ERROR("Unable to copy TestDB.tgz from $TestDbURL");
            }
        }
        mkdir $TestDataDir;
        system("tar -xzf $dataDir/TestDB.tgz -C $TestDataDir");#Note, this does not work in windows...
        if( !-d "$TestDataDir/data/ModelDB" || !-f "$TestDataDir/data/ModelDB/ModelDB.sqlite") {
            ModelSEED::globals::ERROR("TestDB.tgz does not look like I expected!");
        }
        system("sqlite3 $TestDataDir/data/ModelDB/ModelDB.db < $TestDataDir/data/ModelDB/ModelDB.sqlite");
    } 
    # Now copy over $TestDataDir to a tempfile
    my $tmpDir = File::Temp::tempdir();
    $tmpDir =~ s/\/$//;
    File::Copy::Recursive::dircopy($TestDataDir, $tmpDir);
    # Upload $tmpDir/data/ModelDB/ModelDB.sqlite into $tmpDir/data/ModelDB/ModelDB.db
    if( -d "$tmpDir/data/model") {
        $rtv->{'model directory'} = ["$tmpDir/data/model"];
    }
    foreach my $key (keys %{$prod}) {
        if($key =~ /^PPO_tbl_/) {
            if(defined($prod->{$key}->{name}) && $prod->{$key}->{name}->[0] =~ /ModelDB/) {
                my $newConfig = {
                    name => $prod->{$key}->{name},
                    type => $prod->{$key}->{type},
                    status => $prod->{$key}->{status},
                    table => $prod->{$key}->{table},
                    host => ["$tmpDir/data/ModelDB/ModelDB.db"],
                };
                $rtv->{$key} = $newConfig;
            }
        }
    }
    # Create temporary workspace directory
    $rtv->{"Workspace directory"} = [File::Temp::tempdir()];
    return $rtv;
} 
1;
