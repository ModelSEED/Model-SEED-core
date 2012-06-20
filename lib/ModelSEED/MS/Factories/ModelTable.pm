package ModelSEED::MS::Factories::ModelTable;
use Moose;
use common::sense;
use ModelSEED::MS::Model;
use namespace::autoclean;
our $headers = [ "Reaction Id", "Direction", "Compartment Id", "GPR" ];

sub toTable {
    my ($self, $model, $config) = @_;
    $config->{with_headers} //= 0;
    my $reactions = $model->modelreactions;
    my $rows = [];
    foreach my $reaction (@$reactions) {
        my $rxn_id = $reaction->reaction->id;
        my $dir    = $reaction->direction;
        my $cmp_id = $reaction->modelcompartment->label;
        my $gpr    = $self->_make_GPR_string($reaction);
        push(@$rows, [$rxn_id, $dir, $cmp_id, $gpr]);
    }
    unshift(@$rows, $headers) if($config->{with_headers});
    return $rows;
}

sub fromTable {
    my ($self, $table, $model) = @_;
    foreach my $row (@$table) {
        # Skip header row
        next if($row->[0] eq $headers->[0]);
        die "Invalid" unless(@$row == @$headers);
        my ($rxn, $direction, $cmp, $gpr) = @$row;
        $gpr = $self->get_gpr($gpr, $model);
        $cmp = $self->get_cmp($cmp, $model);
        $rxn = $self->get_rxn($rxn, $model);
    }
}

sub fromTableFilename {
    my ($self, $filename, $model) = @_;
    open(my $fh, "<", $filename) || die "Could not find file: $filename"; 
    my $rtv = $self->fromTableFilehandle($fh, $model);
    close($fh);
    return $rtv;
}

sub fromTableFilehandle {
    my ($self, $fh, $model) = @_;
    my $rows = []; 
    while(<$fh>) {
        my $row = [split(/\t/, $_)];
        map { chomp $_ } @$row;
        push(@$rows, $row);
    }
    return $self->fromTable($rows, $model);
}

sub get_cmp {
    my ($self, $cmp_id, $model) = @_;
    return $model->getObject("compartment", { id => $cmp_id });
}

sub _make_GPR_string {
    my ($self, $rxn) = @_;
    my $proteins = $rxn->modelReactionProteins;
    my $data = [];
    my $meta = "{}(),";
    foreach my $protein (@$proteins) {
        my $subunits = $protein->modelReactionProteinSubunits;
        my $units = [];
        foreach my $subunit (@$subunits) {
            my $subunitGenes = $subunit->modelReactionProteinSubunitGenes;
            my $features = [ 
                map { $_->feature->id }
                @$subunitGenes
            ];
            map { $_ =~  s/([$meta])/\\$1/g } @$features;
            push(@$units, "(" .join(",",@$features) . ")");
        }
        push(@$data, "{". join("", @$units) . "}");
    }
    return join("", @$data);
}

1;

