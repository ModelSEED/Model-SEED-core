package BerkTable;

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



use strict;
use DB_File;
use Data::Dumper;

sub TIEHASH
{
    my($class, $file, %opts ) = @_;

    my $self = {
	file => $file,
	hash => {},
	tie => undef,
	results_as_list => 0,
	result_separator => "\n",
    };
    $self->{$_} = $opts{$_} for keys %opts;

    $self->{results_as_list} = 1 if $self->{-split_values};
    return bless $self, $class;
}

sub STORE
{
    my($self, $key, $val) = @_;
    $self->_ensure_tied();
    $self->{hash}->{$key} = $val;
}

sub FETCH
{
    my($self, $key) = @_;
    $self->_ensure_tied();
    my @res = $self->{tie}->get_dup($key);
    if ($self->{-split_values})
    {
	@res = map { [ split(/$;/, $_) ] } @res;
    }
    if ($self->{-results_as_list})
    {
	return \@res;
    }
    else
    {
	return join($self->{-result_separator}, @res);
    }
}

sub FIRSTKEY
{
    my($self) = @_;
    $self->_ensure_tied();
    my $a = scalar keys %{$self->{hash}};
    return each %{$self->{hash}};
}

sub NEXTKEY
{
    my($self) = @_;
    $self->_ensure_tied();
    return each %{$self->{hash}};
}

sub EXISTS
{
    my($self, $key) = @_;
    $self->_ensure_tied();
    return exists $self->{hash}->{$key};
}

sub DELETE
{
    my($self, $key) = @_;
    $self->_ensure_tied();
    return delete $self->{hash}->{$key};
}

sub SCALAR
{
    my($self, $key) = @_;
    $self->_ensure_tied();
    return scalar %{$self->{hash}->{$key}};
}

sub _ensure_tied
{
    my($self) = @_;
    if (!$self->{tie})
    {
	$self->{tie} = tie %{$self->{hash}}, 'DB_File', $self->{file}, O_RDONLY, 0, $DB_BTREE;
    }
}

1;
