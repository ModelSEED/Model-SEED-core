@INC = (
    'C:\Program Files\myRAST\deplib',
    'C:\Program Files\myRAST\lib'
);
my $prog = shift(@ARGV);
do $prog;
if ($@) { die "Failure running $prog: $@\n" }
1;
