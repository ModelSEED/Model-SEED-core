#!/usr/bin/perl
use File::Copy;
use FIG_Config;
use Cwd 'abs_path';

my $config = {
    "ProdDB" => { 'details' => "Production database, production model pipeline",
                  'config' => "/vol/model-dev/MODEL_DEV_DB/ReactionDB/masterfiles/FIGMODELConfig.txt".
                              ":/vol/model-prod/FIGdisk/config/FIGMODELConfig.txt",
                },
    "DevDB" => { 'details' => "Developmental database, production model pipeline",
                 'config' => "/vol/model-dev/MODEL_DEV_DB/ReactionDB/masterfiles/FIGMODELConfig.txt:".
                             "/vol/model-prod/FIGdisk/config/FIGMODELConfig.txt:".
                              "/vol/model-dev/MODEL_DEV_DB/ReactionDB/masterfiles/DevFIGMODELConfig.txt" 
                },
};

my $FIG_ConfigFilename = $ENV{HOME}."/FIGdisk/config/FIG_Config.pm";
my $FIG_ConfigData = [];
if (-e $FIG_ConfigFilename) {
    open( my $FIG_ConfigFH, "<", $FIG_ConfigFilename);
    while( <$FIG_ConfigFH> ) {
        push(@$FIG_ConfigData, $_);
    }
    close($FIG_ConfigFH); 
} else {
    warn "Unable to find FIG_Config.pm at $FIG_ConfigFilename!\nNo changes made!\n";
    exit();
}

my $currConfig;
foreach my $line (@$FIG_ConfigData) {
    if($line =~ /\$FIGMODEL_CONFIG = \"(.*)\"/) {
        my $configLine = $1;
        foreach my $key (keys %$config) {
            if ($configLine eq $config->{$key}->{config}) {
                $currConfig = $key;
                last;
            }
        }
        last;
    }
}
if(not defined($currConfig)) {
    $currConfig = "Unknown";
}
sub changeConfigFile {
    my ($configKey) = @_;
    exec("unset FIGMODEL_CONFIG"); # remove env variable
    my $oldFile = $FIG_ConfigFilename . "." . $currConfig;
    move($FIG_ConfigFilename, $oldFile);
    open(my $newFH, ">", $FIG_ConfigFilename);
    my $printedModelConfig = 0;
    foreach my $line (@$FIG_ConfigData) {
        if($line =~ /\$FIGMODEL_CONFIG =/) {
            print $newFH  "\$FIGMODEL_CONFIG = \"".$config->{$configKey}->{'config'}."\";\n";
            $printedModelConfig = 1;
        } elsif ($line =~ /^1;$/ && !$printedModelConfig) {
            print $newFH "\$FIGMODEL_CONFIG = \"".$config->{$configKey}->{'config'}."\";\n";
            print $newFH $line;
            $printedModelConfig = 1;
        } else {
            print $newFH $line;
        }
    }
    close($newFH);
}
    
my $usage = <<EGASU;
Usage: switch-modeldb [args] [configuration]
Arguments:
    -l      List available configurations
    -h,-?   Prnt this documentation
EGASU
for(my $i=0; $i<@ARGV; $i++) {
    if ($ARGV[$i] eq '-l') {
        print "Config Name\tDetails\n";
        foreach my $k (keys %$config) {
            print $k . "\t" . $config->{$k}->{details} . "\n";
        }
        exit();
    } elsif ($ARGV[$i] eq '-h' || $ARGV[$i] eq "-?") {
        print $usage;
        exit();
    } elsif (defined($config->{$ARGV[$i]})) {
        changeConfigFile($ARGV[$i]);
        exit();
    } else {
        warn "Unknown argument: " . $ARGV[$i] . "!\n";
        exit();
    }
}

print "Database currently set to: $currConfig\nOptions are:\n";
foreach my $key (keys %$config) {
    print $key . "\n";        
}
