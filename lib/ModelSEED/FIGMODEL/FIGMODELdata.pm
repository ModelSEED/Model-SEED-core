#===============================================================================
#
#         FILE:  FIGMODELdata.pm
#
#  DESCRIPTION:  A wrapper around PPO objects that prevents writing to
#                the attributes of owned objects, i.e objects that contain
#                the attribute 'owner' that is != 'master' where that owner
#                is not logged in via figmodel->authenticate. 
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Scott Devoid, devoid@ci.uchicago.edu
#      COMPANY:  University of Chicago
#      VERSION:  1.0
#      CREATED:  03/25/11 11:59:19
#     REVISION:  ---
#===============================================================================
use strict;
package ModelSEED::FIGMODEL::FIGMODELdata;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

sub new {
    my ($class, $ppoObj, $figmodel, $type) = @_;
    my $self = {
        _type => $type,
        _obj => $ppoObj,
        _figmodel => $figmodel,
        _attrs => $ppoObj->attributes(),
    };
    Scalar::Util::weaken($self->{_figmodel});
    return bless $self, $class;
}

sub AUTOLOAD {
    my $self = shift @_;
    my $call = our $AUTOLOAD;
    return if $call =~ /::DESTROY$/;
    $call =~ s/.*://;
    unless(scalar(@_) > 0) {
        return $self->{_obj}->$call();
    } 
    my $value = shift @_; 
    my $database = $self->{_figmodel}->database();
    my $rights = $database->get_object_rights($self->{_obj}, $self->{_type});
    if(defined($rights->{'admin'}) or defined($rights->{'edit'})) {
        $database->clearCache("type:".$self->{_type});
        return $self->{_obj}->$call($value);
    } else {
        Carp::cluck("User " . $self->{_figmodel}->user() . " does not have rights to set attribute ".
            "$call with value $value on object of type " . $self->{_type});
        return $self->{_obj}->$call();
    }
}
1;
