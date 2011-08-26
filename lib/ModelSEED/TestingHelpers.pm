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
use ModelSEED::FIGMODEL;

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
        unless(defined($args)) {
            $args = $self->getDebugFIGMODELConfig();
        }
        $self->{_figmodel} = ModelSEED::FIGMODEL->new($args);
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
    my $args = {
        configFiles => ["/vol/model-dev/MODEL_DEV_DB/ReactionDB/masterfiles/FIGMODELConfig.txt",
                        "/vol/model-dev/MODEL_DEV_DB/ReactionDB/masterfiles/DevFIGMODELConfig.txt",
      #                  {"warn_level" => 0}, # disable warnings
                       ],
    };
    return $args;
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
    
1;
