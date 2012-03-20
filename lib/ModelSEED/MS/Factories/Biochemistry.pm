package ModelSEED::MS::Factories::Biochemistry;
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
use Moose;
use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Compound;
#use ModelSEED::MS::CompoundAlias;
use ModelSEED::MS::Meida;
use ModelSEED::MS::Reaction;
#use ModelSEED::MS::ReactionAlias;

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
        foreach my $type (qw(cpdals rxnals media compartments)) {
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
        compartment   => 'compartments.txt',
    };
    foreach my $file (values %$files) {
        $file = "$dir/$file";
        die "Unable to find $file!" unless (-f "$file");
    }
    my $tables = {%$files};
    my $config = {filename => undef, delimiter => "\t"};
    foreach my $key (keys %$tables) {
        $config->{filename} = $tables->{$key};
        $tables->{$key}
            = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    my $bio = ModelSEED::DB::Biochemistry->new();
    # Compartments
    my $cmps = [];
    for(my $i=0; $i<$tables->{compartment}->size(); $i++) {
        my $row = $tables->{compartment}->get_row($i);
        my $obj = $self->convert("compartment", $row);
        push(@$cmps, $obj);
    }
    $bio->compartments($cmps);
    # Compounds
    my $cpds = [];
    for (my $i = 0; $i < $tables->{compound}->size(); $i++) {
        my $row = $tables->{compound}->get_row($i);
        my $obj = $self->convert("compound", $row);
        push(@$cpds, $obj);
    }
    $bio->compounds($cpds);
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
    my $tempDir = $self->_standardizeDirectory(tempdir());
    foreach my $type (qw(compound reaction cpdals rxnals media compartments)) {
        my $objects = $db->get_objects($type, {});
        my $table = $db->ppo_rows_to_table({filename => "$tempDir/$type.txt"}, $objects); 
        $table->save();
    }
    return $self->newBiochemistryFromDirectory({directory => $tempDir});
}

sub _standardizeDirectory {
    my ($self, $dir) = @_;
    $dir = abs_path($dir);
    $dir =~ s/\/$//;
    return $dir;
}
