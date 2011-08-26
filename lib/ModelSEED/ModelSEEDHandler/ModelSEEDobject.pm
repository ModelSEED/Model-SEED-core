package ModelSEEDObject;
#===============================================================================
#
#         FILE:  ModelSEEDObject.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Scott Devoid (devoid@ci.uchicago.edu) 
#      COMPANY:  University of Chicago 
#      VERSION:  1.0
#      CREATED:  08/25/10 15:19:51
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Carp;

sub new {
    my ($type, $object, $realType) = @_;
    {
        no strict;
        eval("require ModelSEEDObject::$realType");
        die "Failure on require of package ModelSEEDObject::$realType : $@" if ($@);
    }
    my $self = ("ModelSEEDObject::".$realType)->new($object);
    return $self; 
}
1;
