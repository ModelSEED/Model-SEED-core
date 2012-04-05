#===============================================================================
#
#         FILE: ModelSEED::Config::Store
#
#  DESCRIPTION: Parameterized role for serializing and deserializing
#               a INI config entries value that looks like this:
#               
#               [stores]
#               local=type:file;filename:/path/to/foo.db
#               
#               get(stores, local) will then return:
#               { type => 'file', filename => '/path/to/foo.db' }
#               
#               and set(stores, local, HASH_REF) will do the correct thing
#
#               Note that the CHAR "\" can be used as an escape charachter
#               to add ";" or ":" to your configuration.
#
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 04/03/2012 16:42:22
#     REVISION: ---
#===============================================================================
package ModelSEED::Config::Store;
use MooseX::Role::Parameterized;
use Data::Dumper;

parameter type => (
    isa      => 'Str',
    required => 1,
);

parameter class => (
    isa      => 'ClassName',
    required => 1,
);

role {
    my $p     = shift;
    my $TYPE  = $p->type;
    my $CLASS = $p->class;

    around 'get' => sub {
        my ($orig, $self, $section, $key) = @_;
        my $rtv = $self->$orig($section, $key);
        if ($section =~ /stores/ && defined($rtv) && $rtv =~ /type:$TYPE/) {
            return _parse($rtv);
        } else {
            return $rtv;
        }
    };

    around 'set' => sub {
        my ($orig, $self, $section, $key, $value) = @_;
        if (   $section =~ /stores/
            && defined($value)
            && ref($value)
            && defined($value->{type})
            && $value->{type} =~ /$TYPE/)
        {
            $value = _serialize($value);
        }
        return $self->$orig($section, $key, $value);
    };
};

sub _serialize {
    my ($value) = @_;
    my $tmp = {};
    foreach my $key (keys %$value) {
        $tmp->{$key} = $key . ":" . $value->{$key};
    }
    return join(";", map { $tmp->{$_} } sort keys %$tmp);
}

sub _parse {
    my ($string) = @_;
    my $sections = [split(/(?<!\\);/, $string)];
    my $hash = {};
    foreach my $section (@$sections) {
        my ($key, $value) = split(/(?<!\\):/, $section);
        $hash->{$key} = $value;
    }
    return $hash;
}

1;
