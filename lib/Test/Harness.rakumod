
unit package Test::Harness:auth<github:littlebenlittle>:ver<0.0.1>;

use META6::Query;

class Runner {
    has IO::Path @.files;
    has Str @.flags;
    has Bool $.label-streams;
    has Bool $.parallel;
    has IO::Path @!pass;
    has IO::Path @!fail;
    has $!bufs = {};
    method run {
        if $.parallel {
            race for @.files { self.run-test: $_  }
        } else {
            for @.files { self.run-test: $_  }
        }
        return @!fail.elems == 0;
    }
    method prepare-output(Str:D $line, Str:D $stream-name) {
        my $ret = '';
        $ret ~= "$stream-name: " if $.label-streams;
        $ret ~= "$line\n";
        return $ret;
    }
    method run-test(IO() $filename) {
        my @cmd = « $*EXECUTABLE {@.flags} $filename »;
        my $proc = Proc::Async.new: @cmd, :out, :err;
        my $buf := $!bufs{$filename};
        $buf = '';
        my $signals = signal(SIGHUP).merge(signal(SIGINT)).merge(signal(SIGTERM));
        react {
            whenever $proc.stdout.lines { $buf ~= self.prepare-output($_, 'OUT') }
            whenever $proc.stderr.lines { $buf ~= self.prepare-output($_, 'ERR') }
            whenever $signals { $proc.kill: $_ }
            whenever $proc.start {
                @!pass.push: $filename if     .exitcode == 0;
                @!fail.push: $filename unless .exitcode == 0;
                done
            }
        }
    }
    method report {
        my $buf = '';
        for @!pass.sort -> $filename {
            $buf ~= "# PASS {$filename}\n";
        }
        for @!fail.sort -> $filename {
            $buf ~= "# FAIL {$filename}\n\n";
            $buf ~= $!bufs{$filename};
        }
        return $buf;
    }
}

sub MAIN(
    Str  $base-dir;
    Bool :$l = False; #= label streams
    Bool :$p = True; #= spawn parallel sub-processes
) is export(:MAIN) {
    my @files = $base-dir.IO.add('t').dir.list.grep: * ~~ /'.t'$/;
    my $root-dir = META6::Query::root-dir $base-dir;
    my $lib-dir  = $root-dir.add('lib');
    my $runner = Runner.new(
        files => @files,
        flags => « -I $lib-dir »,
        label-streams => $l,
        parallel => $p,
    );
    my $pass = $runner.run;
    say $runner.report;
    note "# ALL TESTS PASS" if $pass;
    exit $pass ?? 1 !! 0;
}
