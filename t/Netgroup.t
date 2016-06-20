#! /usr/bin/env perl

# User::Netgroup test

package main;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin" . "/../lib";

use User::Netgroup;

use YAML;

while( my $u = User::Netgroup::nextnetgrent() ){
	print YAML::Dump $u;
}
