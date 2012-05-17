
# This is a SAS component.

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

package gjolib;

#  Invoke with:
#
#     use gjolib;


#  Exported functions:
#
#     file_root_name( $path )
#     script_name( )
#     wrap_text( $str [, $len [, $indent_1 [, $indent_n]]] )

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
        file_root_name
        script_name
        wrap_text
        );

use strict;


#-----------------------------------------------------------------------------
#  Return the base name of a file (no directory & remove 1 extension)
#
#     $root_name = file_root_name( $path )
#-----------------------------------------------------------------------------
sub file_root_name {
    $_ = shift;

    s/^.*\///;     # remove all directory prefixes
    s/\.[^.]*$//;  # remove one dot something suffix
    return $_;
}



#-----------------------------------------------------------------------------
#  Return the name of the invoked command
#
#     $scriptname = script_name( )
#-----------------------------------------------------------------------------
sub script_name {
    $_ = $0;
    s/^.*\///;     # remove all directory prefixes
    return $_;
}



#-----------------------------------------------------------------------------
#  Return a string with text wrapped to defined line lengths:
#
#     $wrapped_text = wrap_text( $str )                  # default len   =  80
#     $wrapped_text = wrap_text( $str, $len )            # default ind   =   0
#     $wrapped_text = wrap_text( $str, $len, $indent )   # default ind_n = ind
#     $wrapped_text = wrap_text( $str, $len, $indent_1, $indent_n )
#-----------------------------------------------------------------------------
sub wrap_text {
    my ($str, $len, $ind, $indn) = @_;

    defined($str)  || die "wrap_text called without a string\n";
    defined($len)  || ($len  =   80);
    defined($ind)  || ($ind  =    0);
    ($ind  < $len) || die "wrap error: indent greater than line length\n";
    defined($indn) || ($indn = $ind);
    ($indn < $len) || die "wrap error: indent_n greater than line length\n";

    $str =~ s/\s+$//;
    $str =~ s/^\s+//;
    my ($maxchr, $maxchr1);
    my (@lines) = ();

    while ($str) {
        $maxchr1 = ($maxchr = $len - $ind) - 1;
        if ($maxchr >= length($str)) {
            push @lines, (" " x $ind) . $str;
            last;
        }
        elsif ($str =~ /^(.{0,$maxchr1}\S)\s+(\S.*)$/) { # no expr in {}
            push @lines, (" " x $ind) . $1;
            $str = $2;
        }
        elsif ($str =~ /^(.{0,$maxchr1}-)(.*)$/) {
            push @lines, (" " x $ind) . $1;
            $str = $2;
        }
        else {
            push @lines, (" " x $ind) . substr($str, 0, $maxchr);
            $str = substr($str, $maxchr);
        }
        $ind = $indn;
    }

    return join("\n", @lines);
}


1;
