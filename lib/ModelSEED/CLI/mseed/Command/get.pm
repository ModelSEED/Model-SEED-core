#
#===============================================================================
#
#         FILE: mseed get
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 04/05/2012 15:35:33
#     REVISION: ---
#===============================================================================
package ModelSEED::CLI::mseed::Command::get;
use base 'App::Cmd::Command';
sub execute {
    my ($self, $opts, $args) = @_;
    return;
}

sub abstract {
    return "List and retrive objects from workspace or datastore.";
}

1;
