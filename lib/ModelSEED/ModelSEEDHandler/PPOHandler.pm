package ModelSEEDHandler::PPOHandler;
#===============================================================================
#
#         FILE:  PPOHandler.pm
#
#  DESCRIPTION:  Interface linking a PPO database connection to the
#                ModelSEEDHandler.
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Scott Devoid (devoid@ci.uchicago.edu)
#      COMPANY:  Unviersity of Chicago 
#      VERSION:  1.0
#      CREATED:  08/25/10 14:59:23
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use DBMaster;
use ModelSEEDObject;

sub new {
    my ($type, $config) = @_;
    my @parts = split(/\|/, $config); 
    my $configHashRef = {};
    for (my $i=0; $i<@parts; $i++) {
        my $piece = $parts[$i];
        my ($key, $value) = split(/;/, $piece);
        $configHashRef->{$key} = $value;
    }
    my $db = DBMaster->new(%$configHashRef);  
    Confess("There was an error in connecting to the database: $@") if($@);
    my $self = { 'db' => $db, };
    return bless $self;
}

sub get {
    my ($self, $arg1, $arg2) = @_;
    if(defined($arg1) && ref($arg1) eq "ARRAY") {
        # complex query 
    } elsif(defined($arg1) && defined($arg2) && ref($arg2) eq "HASH") {
        my $query = $self->{'db'}->$arg1->get_objects($arg2);
        for(my $i=0; $i<@$query; $i++) {
            $query->[$i] = ModelSEEDObject->new($query->[$i], "PPOObject");
        }
        return $query;
    } else { 
        Confess("Unknown call to get()!");
    }
}
    
1;
