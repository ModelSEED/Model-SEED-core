#===============================================================================
#
#         FILE: Biochemistry.pm
#
#  DESCRIPTION: A factory object for creating a biochemistry. This
#               can be used for importing a biochemistry from PPO or
#               a flat-file based directory structure containing:
#                   /biochemistry/
#                       reaction.txt
#                       compound.txt
#                       rxnals.txt      (optional)
#                       cpdals.txt      (optional)
#                       media.txt       (optional)
#                       compartment.txt (optional)
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 03/19/2012 11:40:24
#     REVISION: ---
#===============================================================================
use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Compound;
#use ModelSEED::MS::CompoundAlias;
use ModelSEED::MS::Media;
use ModelSEED::MS::Reaction;
#use ModelSEED::MS::ReactionAlias;
use DateTime;
package ModelSEED::MS::Factories::Biochemistry;
use Moose;
use namespace::autoclean;
use Data::Dumper;

has conversionFns => (is => 'rw', isa => 'HashRef', builder => '_makeConversionFns', lazy => 1);

# Generate a new biochemistry object from
# a directory structure.
sub newBiochemistryFromDirectory {
    my ($self, $args) = @_;
    unless(defined($args->{directory})) {
        die "Required argument 'directory' not defined";
    }
    my $dir = $self->_standardizeDirectory($args->{directory});
    # If a FIGMODELdatabase was supplied, pull in missing data
    # from this database where $args->{type} is true.
    if(defined($args->{database}) && ref($args->{database})) {
        my $db = $args->{database};
        foreach my $type (qw(cpdals rxnals media compartment)) {
            my $objects = $db->get_objects($type, {});
            my $table = $db->ppo_rows_to_table({filename => "$dir/$type.txt"}, $objects); 
            $table->save();
        }
    }
    my $files = {
        reaction       => 'reaction.txt',
        compound       => 'compound.txt',
        compound_alias => 'cpdals.txt',
        reaction_alias => 'rxnals.txt',
        media          => 'media.txt',
        compartment   => 'compartment.txt',
    };
    foreach my $file (values %$files) {
        $file = "$dir/$file";
        die "Unable to find $file!" unless (-f "$file");
    }
    my $tables = {%$files};
    my $config = {filename => undef, delimiter => "\t", itemDelimiter => ";"};
    foreach my $key (keys %$tables) {
        $config->{filename} = $tables->{$key};
        $tables->{$key}
            = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    my $bio = ModelSEED::MS::Biochemistry->new();
    # Compartments
    for(my $i=0; $i<$tables->{compartment}->size(); $i++) {
        my $row = $tables->{compartment}->get_row($i);
        my $obj = $self->convert("compartment", $row, $bio);
        warn Dumper $obj;
        $bio->add("Compartment", $obj);
    }
    # Compounds
    my $cpds = [];
    for (my $i = 0; $i < $tables->{compound}->size(); $i++) {
        my $row = $tables->{compound}->get_row($i);
        my $obj = $self->convert("compound", $row, $bio);
        $bio->add("Compound", $obj);
        #push(@$cpds, $obj);
    }
    #$bio->compounds($cpds);
=head
    # CompoundAliases
    my $aliasRepeats = {};
    for (my $i = 0; $i < $tables->{compound_alias}->size(); $i++) {
        my $row = $tables->{compound_alias}->get_row($i);
        my $hash = $self->convert("compound_alias", $row);
        my $error;
        ($error, $aliasRepeats)
            = checkAliases($aliasRepeats, $hash, "compound")
            if (defined($hash));
        if (!defined($hash) || $error) {
            push(
                @{$missed->{compound_alias}},
                $row->{COMPOUND}->[0] . ":" . $row->{type}->[0]
            );
            next;
        }
        my $RDB_compound_alias
            = $self->getOrCreateObject("compound_alias", $hash);
    }

    # Reactions
    for (my $i = 0; $i < $tables->{reaction}->size(); $i++) {
        my $row = $tables->{reaction}->get_row($i);
        my $hash = $self->convert("reaction", $row);
        unless (defined($hash)) {
            push(@{$missed->{reaction}}, $row->{id}->[0]);
            next;
        }
        my $RDB_reaction = $self->getOrCreateObject("reaction", $hash);
        $RDB_biochemistry->add_reactions($RDB_reaction);

        # Reagents and DefaultTransportedReagents
        my $data = $self->generateReactionDataset($row, $missed);
        foreach my $reagent (@{$data->{reagents}}) {
            next if (!defined($reagent));
            my $RDB_reagent = $self->getOrCreateObject("reagent", $reagent);
        }
        foreach my $rt (@{$data->{default_transported_reagents}}) {
            next if (!defined($rt));
            my $RDB_rt
                = $self->getOrCreateObject("default_transported_reagent",
                $rt);
        }

    }

    # ReactionAlias
    for (my $i = 0; $i < $tables->{reaction_alias}->size(); $i++) {
        my $row = $tables->{reaction_alias}->get_row($i);
        my $hash = $self->convert('reaction_alias', $row);
        next
            if (!defined($hash)
            || $hash->{type} eq "name"
            || $hash->{type} eq "searchname");
        my $error;
        ($error, $aliasRepeats)
            = checkAliases($aliasRepeats, $hash, "reaction")
            if (defined($hash));
        if (!defined($hash) || $error) {
            push(
                @{$missed->{reaction_aliases}},
                $row->{REACTION}->[0] . ":" . $row->{type}->[0]
            );
            next;
        }
        my $RDB_reaction_alias
            = $self->getOrCreateObject("reaction_alias", $hash);
    }

    # Media
=cut
    return $bio;
}

sub newBiochemistryFromPPO {
    my ($self, $args) = @_;
    unless(defined($args->{database})) {
        die "Required argument 'database' not defined";
    }
    my $db = $args->{database};
    my $tempDir = $self->_standardizeDirectory(File::Temp::tempdir());
    foreach my $type (qw(compound reaction cpdals rxnals media compartment)) {
        my $objects = $db->get_objects($type, {});
        my $config = {
            filename => "$tempDir/$type.txt",
            delimiter => "\t",
            itemDelimiter => ";",
        };
        my $table = $db->ppo_rows_to_table($config, $objects); 
        $table->save();
    }
    return $self->newBiochemistryFromDirectory({directory => $tempDir});
}

sub _standardizeDirectory {
    my ($self, $dir) = @_;
    $dir = Cwd::abs_path($dir);
    $dir =~ s/\/$//;
    return $dir;
}

sub _makeConversionFns {
    my ($self, $type, $row) = @_;
    # Return a DateObject given default epoch timestamp
    my $date = sub {
        my ($self, $row) = @_;
        return ($row->{modificationDate}->[0])
            ? DateTime->from_epoch(epoch => $row->{modificationDate}->[0])
            : ($row->{creationDate}->[0])
            ? DateTime->from_epoch(epoch => $row->{creationDate}->[0])
            : DateTime->now();
    };
    my $f = {};
    $f->{compound} = sub {
        my ($self, $row) = @_;
        return {
            id            => $row->{id}->[0],
            name          => $row->{name}->[0],
            abbreviation  => $row->{abbrev}->[0],
            formula       => $row->{formula}->[0],
            mass          => $row->{mass}->[0],
            defaultCharge => $row->{charge}->[0],
            deltaG        => $row->{deltaG}->[0],
            deltaGErr     => $row->{deltaGErr}->[0],
            modDate       => $date->($row),
        };
    };
    $f->{compound_alias} = sub {
        my ($self, $row, $ctx) = @_;
        my $uuid = $self->uuidCache("compound", $row->{COMPOUND}->[0], $ctx);
        return undef unless ($uuid);
        return {
            type          => $row->{type}->[0],
            alias         => $row->{alias}->[0],
            compound_uuid => $uuid,
        };
    };
    $f->{reaction} = sub {
        my ($self, $row, $ctx) = @_;
        my $codes = {reversibility => '', thermoReversibility => ''};
        foreach my $key (keys %$codes) {
            my ($forward, $reverse) = (0, 0);
            $forward = 1
                if (defined($row->{$key}->[0]) && $row->{$key}->[0] =~ />/);
            $reverse = 1
                if (defined($row->{$key}->[0]) && $row->{$key}->[0] =~ /</);
            if (!$forward && $reverse) {
                $codes->{$key} = "<";
            } elsif (!$reverse && $forward) {
                $codes->{$key} = ">";
            } else {
                $codes->{$key} = "=";
            }
        }
        my $parts = parseReactionEquation($row);
        unless (@$parts) {
            return undef;
        }
        my $cmp = determinePrimaryCompartment($parts, $ctx);
        my $cmp_uuid = $self->uuidCache("compartment", $cmp, $ctx);
        unless ($cmp_uuid) {
            warn "Could not identify compartment for reaction: "
                . $row->{id}->[0]
                . " with compartment "
                . $cmp . "\n";
            return undef;
        }
        return {
            id                  => $row->{id}->[0],
            name                => $row->{name}->[0],
            abbreviation        => $row->{abbrev}->[0],
            modDate             => $date->($row),
            equation            => $row->{equation}->[0],
            deltaG              => $row->{deltaG}->[0],
            deltaGErr           => $row->{deltaGErr}->[0],
            reversibility       => $codes->{reversibility},
            thermoReversibility => $codes->{thermoReversibility},
            compartment_uuid    => $cmp_uuid,
        };
    };
    $f->{reaction_alias} = sub {
        my ($self, $row, $ctx) = @_;
        my $uuid = $self->uuidCache("reaction", $row->{REACTION}->[0], $ctx);
        return undef unless ($uuid);
        return {
            type          => $row->{type}->[0],
            alias         => $row->{alias}->[0],
            reaction_uuid => $uuid,
        };
    };
    $f->{reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->uuidCache("reaction", $row->{reaction}->[0], $ctx);
        my $cpd = $self->uuidCache("compound", $row->{compound}->[0], $ctx);
        unless (defined($rxn) && defined($cpd)) {
            return undef;
        }
        return {
            reaction_uuid    => $rxn,
            compound_uuid    => $cpd,
            coefficient      => $row->{coefficient}->[0],
            cofactor         => $row->{cofactor}->[0] || undef,
            compartmentIndex => $row->{compartmentIndex}->[0],
        };
    };
    $f->{default_transported_reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->uuidCache("reaction",    $row->{reaction}->[0], $ctx);
        my $cpd = $self->uuidCache("compound",    $row->{compound}->[0], $ctx);
        my $cmp = $self->uuidCache("compartment", $row->{compartment}->[0], $ctx);
        unless (defined($rxn) && defined($cmp) && defined($cpd)) {
            my $str
                = (!defined($rxn)) ? "no reaction\n"
                : (!defined($cpd)) ? "no cpd\n"
                :                    "no compartment\n";
            warn $str;
            return undef;
        }
        return {
            reaction_uuid        => $rxn,
            compound_uuid        => $cpd,
            compartment_uuid     => $cmp,
            compartmentIndex     => $row->{compartmentIndex}->[0],
            transportCoefficient => $row->{transportCoefficient}->[0],
            isImport             => $row->{isImport}->[0],
        };
    };
    $f->{compartment} = sub {
        my ($self, $row) = @_;
        warn Dumper $row;
        return {
            id      => $row->{id}->[0],
            name    => $row->{name}->[0],
            modDate => $date->($row),
        };
    };
    return $f;

}


# returns the compartment hierarchy (hash of 'id' => level)
# e.g. e => 0, c => 2
sub compartmentHierarchy {
    my $self = shift;
    my $set  = shift;
    my $ctx  = shift;
    $ctx->{compartmentHierarchy} = $set if(defined($set));
    return $self->{compartmentHierarchy};
}

sub convert {
    my ($self, $type, $row, $ctx) = @_;
    my $f = $self->conversionFns->{$type};
    die "No converter for $type!" unless(defined($f));
    return $f->($self, $row, $ctx);
}

sub uuidCache {
    my ($self, $type, $key, $ctx) = @_;
    my $map = {
        compound => { type => 'Compound', key => 'id' },
        reaction => { type => 'Reaction', key => 'id' },
        compartment => { type => 'Compartment', key => 'id' },
    };
    my $Type = $map->{$type}->{type};
    my $KeyName = $map->{$type}->{key};
    die "Bad call to uuidCache" unless (defined($Type) && defined($KeyName));
    my $o = $ctx->getObject($type, { $KeyName => $key });
    return $o->uuid;
}

sub parseReactionEquation {
    my ($row)    = @_;
    my $Equation = $row->{equation}->[0];
    my $Reaction = $row->{id}->[0];
    return parseReactionEquationBase($Equation, $Reaction);
}

sub parseReactionEquationBase {
    my ($Equation, $Reaction) = @_;
    my $Parts = [];
    if (defined($Equation)) {
        my @TempArray            = split(/\s/, $Equation);
        my $CurrentlyOnReactants = 1;
        my $Coefficient          = 1;
        for (my $i = 0; $i < @TempArray; $i++) {
            if (   $TempArray[$i] =~ m/^\(([\.\d]+)\)$/
                || $TempArray[$i] =~ m/^([\.\d]+)$/)
            {
                $Coefficient = $1;
            } elsif ($TempArray[$i] =~ m/(cpd\d\d\d\d\d)/) {
                $Coefficient *= -1 if ($CurrentlyOnReactants);
                my $NewRow;
                $NewRow->{"reaction"}->[0]    = $Reaction;
                $NewRow->{"compound"}->[0]    = $1;
                $NewRow->{"compartment"}->[0] = "c";
                $NewRow->{"coefficient"}->[0] = $Coefficient;
                if ($TempArray[$i] =~ m/cpd\d\d\d\d\d\[([a-zA-Z]+)\]/) {
                    $NewRow->{"compartment"}->[0] = lc($1);
                }
                push(@$Parts, $NewRow);
                $Coefficient = 1;
            } elsif ($TempArray[$i] =~ m/=/) {
                $CurrentlyOnReactants = 0;
            }
        }
    }
    return $Parts;
}

# Situate the reaction in the cytosol (c) unless it does not exist.
# If it does not exist, select the innermost compartment.
sub determinePrimaryCompartment {
    my ($self, $parts, $ctx) = @_;
    my $hierarchy = $self->compartmentHierarchy($ctx);
    my ($innermostScore, $innermost);
    foreach my $part (@$parts) {
        my $cmp = $part->{compartment}->[0];
        if ($cmp eq 'c') {
            $innermost = $cmp;
            last;
        }
        my $score = $hierarchy->{$cmp};
        if (!defined($innermostScore) || $score > $innermostScore) {
            $innermostScore = $score;
            $innermost      = $cmp;
        }
    }
    return $innermost;
}

__PACKAGE__->meta->make_immutable;
1;
