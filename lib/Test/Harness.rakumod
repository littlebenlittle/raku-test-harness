
unit package Test::Harness:auth<github:littlebenlittle>:ver<0.0.0>;

my Bool $use-labels;

sub MAIN(
    Str  $base-dir;
    Str  :$I; #= library path to include
    Bool :$l; #= label streams
) is export(:MAIN) {
    my @t-files = $base-dir.IO.add('t').dir.list.grep: * ~~ /'.t'$/;
    my @flag-strings = ();
    @flag-strings.push("-I $I") if $I;
    $use-labels = $l;
    my $bufs = {};
    my @pass = ();
    my @fail = ();
    race for @t-files -> $filename {
        my @cmd = « $*EXECUTABLE @flag-strings[] $filename »;
        my $proc = Proc::Async.new: @cmd, :out, :err;
        my $buf := $bufs{$filename};
        $buf = '';
        my $signals = signal(SIGHUP).merge(signal(SIGINT)).merge(signal(SIGTERM));
        react {
            whenever $proc.stdout.lines { $buf ~= prepare-output($_, 'OUT') }
            whenever $proc.stderr.lines { $buf ~= prepare-output($_, 'ERR') }
            whenever $signals { $proc.kill: $_ }
            whenever $proc.start {
                @pass.push: $filename if .exitcode == 0;
                @fail.push: $filename if .exitcode != 0;
                done
            }
        }
    }
    for @pass.sort -> $filename {
        note "# PASS {$filename}";
    }
    for @fail.sort -> $filename {
        note "# FAIL {$filename}\n";
        note $bufs{$filename};
    }
    my $pass = @fail.elems == 0;
    note "# ALL TESTS PASS" if $pass;
    exit $pass ?? 1 !! 0;
}

sub prepare-output(Str:D $line, Str:D $stream-name) {
    my $ret = '';
    $ret ~= "$stream-name: " if $use-labels;
    $ret ~= "$line\n";
    return $ret;
}

