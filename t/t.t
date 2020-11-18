use v6;

use Test;

use Test::Harness;

my token sep  { \\ | _ | \/ | \- | \. }
my token file { [ <&sep> | <alnum> ]+ }

my $root-dir = $?FILE.IO.dirname.IO.dirname.IO;
my $t-dir    = $root-dir.add('resources').add('fixtures');
my $lib-dir  = $root-dir.add('lib');

my @files = $t-dir.dir.grep(* ~~ /'.t'$/);
my @flags = « "-I=$lib-dir" »;

my $runner = Test::Harness::Runner.new(
    files => @files,
    flags => @flags,
    :label-streams,
);

$runner.run;
my @lines = $runner.report.lines;

plan 5;


cmp-ok @lines[0], '~~', / '# PASS ' <&file> /, 'first line';
cmp-ok @lines[1], '~~', / '# FAIL ' <&file> /, 'second line';
is @lines[3..6].join("\n"), q:to/EOS/.trim, 'lines 3 thru 6';
OUT: 1..2
OUT: ok 1 - some passing test
OUT: not ok 2 - some failing test
ERR: # Failed test 'some failing test'
EOS
cmp-ok @lines[7], '~~', / 'ERR: # at ' <&file> ' line 8' /, 'seventh line';
is @lines[8], 'ERR: # You failed 1 test of 2', 'line 8';

done-testing;

