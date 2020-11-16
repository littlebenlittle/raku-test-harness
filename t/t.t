use v6;

use Test;

class Unit {
	has $.name;
}

my @units = [
];

plan @units.elems;

ok False, .name for @units;

done-testing;

