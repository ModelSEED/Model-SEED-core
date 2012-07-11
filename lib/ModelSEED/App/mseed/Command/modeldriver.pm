package ModelSEED::App::mseed::Command::modeldriver;
use Try::Tiny;
use List::Util;
use File::Temp;
use Class::Autouse qw(
    ModelSEED::Configuration
    ModelSEED::App::Helpers
    ModelSEED::Auth::Factory
    ModelSEED::Store
    ModelSEED::ModelDriver
);
use base 'App::Cmd::Command';

sub abstract { return "Acess ModelDriver commands"; }

sub usage_desc { return "ms modeldriver [subcommand] [arguments]"; }

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory->new->from_config;
    my $username = $auth->username;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new;
    my $driver = ModelSEED::ModelDriver->new;
    if(@$args == 0 || $args->[0] =~ /help/ || $args->[0] =~ /man/) {
        print <<END;
Welcome to the Model SEED! You are currently logged in as: $username
How to use the Model Driver:

Print the argument list expected by the function:

    \$ ms modeldriver usage <function-name>

Call the function with arguments:

    \$ ms modeldriver <function-name> -arg_name arg_value ...

    \$ ms modeldriver <function-name>?<arg1>?<arg2>

Standard notation is "-name value". The question mark notation
requires that the arguments are defined in a specific order.
END
        exit; 
    }
    for (my $i=0; $i < @$args; $i++) {
        $args->[$i] =~ s/\x{d}//g;
    }
    my $Status = "";
    my $currentFunction;
    my $functions;
    my $lastKey;
    my $lastKeyType;
    my $prefixes = ["ms","mdl","db","bc","fba","gen","sq"];
    for (my $i=0; $i < @$args; $i++) {
        for (my $j=0; $j < @{$prefixes}; $j++) {
            my $search = "^".$prefixes->[$j]."-";
            my $prefix = $prefixes->[$j];
            $args->[$i] =~ s/$search/$prefix/g;
        }
        $args->[$i] =~ s/___/ /g;
        $args->[$i] =~ s/\.\.\./(/g;
        $args->[$i] =~ s/,,,/)/g;
        if ($args->[$i] =~ m/^finish\?(.+)/) {
            $driver->finishfile($1);
        } elsif ($args->[$i] =~ m/\?/) {
            my $subarray = [split(/\?/,$args->[$i])];
            if (length($subarray->[0]) > 0) {
                if ($driver->isCommandLineFunction($subarray->[0]) == 1) {
                    if (defined($currentFunction)) {
                        push(@{$functions},$currentFunction);
                    }
                    $currentFunction = {
                        name => shift(@{$subarray}),
                        argHash => {},
                        argList => []	
                    };
                }
            }
            push(@{$currentFunction->{argList}},@{$subarray});
            $lastKey = @{$currentFunction->{argList}}-1;
            $lastKeyType = "argList";
        } elsif ($args->[$i] =~ m/\^finish$/ && defined($args->[$i+1])) {
            $driver->finishfile($args->[$i+1]);
            $i++;
        } elsif ($args->[$i] =~ m/^usage\?(.+)/) {
            my $function = $1;
            $driver->usage($function);
        } elsif ($args->[$i] =~ m/^usage$/ && defined($args->[$i+1])) {
            $driver->usage($args->[$i+1]);
            $i++;
        } elsif ($args->[$i] =~ m/^-usage$/ || $args->[$i] =~ m/^-help$/ ||  $args->[$i] =~ m/^-man$/) {
            if (defined($currentFunction->{name})) {
                $driver->usage($currentFunction->{name});
            }
            $i++;
        } elsif ($args->[$i] =~ m/^\-(.+)/) {
            $lastKey = $1;
            $lastKeyType = "argHash";
            $currentFunction->{argHash}->{$lastKey} = $args->[$i+1];
            $i++;
        } elsif ($driver->isCommandLineFunction($args->[$i]) == 1) {
            if (defined($currentFunction)) {
                push(@{$functions},$currentFunction);
            }
            $currentFunction = {
                name => $args->[$i],
                argHash => {},
                argList => []	
            };
        } else {
            if (defined($lastKeyType) && $lastKeyType eq "argHash") {
                $currentFunction->{argHash}->{$lastKey} .= " ".$args->[$i];
            }  elsif (defined($lastKeyType) && $lastKeyType eq "argList") {
                $currentFunction->{argList}->[$lastKey] .= " ".$args->[$i];
            } else {
                push(@{$currentFunction->{argList}},$args->[$i]);	
            }
        }
    }
    if (defined($currentFunction)) {
        push(@{$functions},$currentFunction);
    }
    #Calling functions
    for (my $i=0; $i < @{$functions}; $i++) {
        my $function = $functions->[$i]->{name};
        print $function."\n";
        my @Data = ($function);
        if (keys(%{$functions->[$i]->{argHash}}) > 0) {
            push(@Data,$functions->[$i]->{argHash});
        } else {
            push(@Data,@{$functions->[$i]->{argList}});
        }
        try {
            my $driverOutput = $driver->$function(@Data);
            print $driverOutput->{message}."\n\n";
        } catch {
            printErrorLog($_);
        };
    }
    #Printing the finish file if specified
    $driver->finish($Status);

    my $refs = [];
    if (@$args) {
        $refs = $args;
    } else {
        $self->usage_error("Must provide at least one reference");
    }
    # Check if any of the refs are the string "-"
    # which means read refs from STDIN, -0 if \0 terminated
    for(my $i=0; $i<@$refs; $i++) {
        if($refs->[$i] eq "-") {
            my $otherRefs = [];
            while(<STDIN>) {
                chomp $_;
                push(@$otherRefs, $_);
            }
            splice(@$refs, $i, 1, @$otherRefs);
            last;
        }
    }
    my $cache = {};
    my $output = [];
    my $JSON = JSON->new->utf8(1);
    foreach my $ref (@$refs) {
        my $o = $self->get_object_deep($cache, $store, $ref);
        if(ref($o) eq 'ARRAY') {
            push(@$output, @$o);
        } else {
            push(@$output, $o);
        }
    }
    my $fh = *STDOUT;
    if($opts->{file}) {
        open($fh, "<", $opts->{file}) or
            die "Could not open file: " .$opts->{file} . ", $@\n";
    }
    my $delimiter;
    $delimiter = "\0" if($opts->{0});
    $delimiter = "\n" if($opts->{newline});
    if (defined $delimiter) {
        print $fh join($delimiter, map { $JSON->encode($_) } @$output);
    } else {
        print $fh $JSON->encode($output);
    }
    close($fh);
    return;
}

sub printErrorLog {
    my $errorMessage = shift @_;
    my $config = ModelSEED::Configuration->instance;
    if($errorMessage =~ /^\"\"(.*)\"\"/) {
        $actualMessage = $1;
    }
    {
        # Pad error message with four spaces
        $errorMessage =~ s/\n/\n    /g;
        $errorMessage = "    ".$errorMessage; 
    }
    my $gitSha = "";
    {
        my $cwd = Cwd::getcwd();
        chdir $ENV{'MODEL_SEED_CORE'};
        $gitSha = `git show-ref --hash HEAD`;
        chdir $cwd;
    }
    chomp $gitSha;
    my $errorDir = $config->config->{error_dir};
    mkdir $errorDir unless(-d $errorDir);
    my ($errorFH, $errorFilename) = File::Temp::tempfile("error-XXXXX", DIR => $errorDir);
    $errorFilename =~ s/\\/\//g;
    print $errorFH <<MSG;
> ModelDriver encountered an unrecoverable error:

$errorMessage

> Model-SEED-core revision: $gitSha
MSG
    my $viewerMessage = <<MSG;
Whoops! We encountered an unrecoverable error.

MSG
    if(defined($actualMessage)) {
        $viewerMessage .= $actualMessage."\n\n";
    }
    $viewerMessage .= <<MSG;

View error using the "ms error" command.

Have you updated recently? ( git pull )
Have you changed your configuration? ( ms-config )

If you are still having problems, please submit a ticket
copying the contents of the error file printed above to:

https://github.com/ModelSEED/Model-SEED-core/issues/new

Thanks!
MSG
    print $viewerMessage;
}
1;
