#! /usr/bin/env perl

# KeyValue.t : test of User::EntDB::Util::KeyValue

package main;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin" . "/../lib";

use User::EntDB::Util::KeyValue;
use YAML;

my $test_default_var=<<EOF
k1 v1
k2  v2
k3	v3
k4 	v4 v4
EOF
;

my $test_multi_var=<<EOF
# /etc/mail/aliases
www:	root
daemon: root
root: user1 user2
EOF
;

sub test_default {
	print "test_default\n";

	my $kv = User::EntDB::Util::KeyValue->new();

	my $expected = [
		{ key => 'k1', val => 'v1' },
		{ key => 'k2', val => 'v2' },
		{ key => 'k3', val => 'v3' },
		{ key => 'k4', val => 'v4 v4' },
	];

	my $e;

	foreach(split /\n/, $test_default_var) {

		my $m = $kv->match($_);
		$e = shift @{$expected};

		if($m) {
			if($e->{key} eq $m->{key} && $e->{val} eq $m->{val}) {

				print "key: " . $m->{key} . " "
					. "val: " . $m->{val}
					. "\n";

			}
			else {
				return 1;
			}
		}
		else {
			return 1;
		}
	}

	return 0;

}

sub test_multi {

	print "test_multi\n";

	# aliases(5) parser
	my $kv = User::EntDB::Util::KeyValue->new({
		'rx' => '((?:\w|\d)*):\s+(.*)',
		'skiprx' => '^\s*#',
		'multi' => '\s+'
	}); 

	my $expected = [
		{ key => 'www', val => [ 'root' ] },
		{ key => 'daemon', val => [ 'root' ] },
		{ key => 'root', val => [ 'user1', 'user2' ] }
	];

	my $e;

	foreach(split /\n/, $test_multi_var) {

		# skip comments -
		# matcher won't match -
		# usage note - this implies can't just 'while match' ...

		next if $kv->skip($_);
		my $m = $kv->match($_);

		$e = shift @{$expected};
		if($m) {

			my $ev;
			my $vstr = '';
			my $err = 0;

			foreach my $mv (@{$m->{val}}) {
				$ev = shift @{$e->{val}};

				if($mv eq $ev) {
					$vstr .= "\nval: $mv";
				}
				else {
					$err = 1;
				}

			}
			if(!$err) {
				print "key: " . $m->{key}
					if $m->{key} eq $e->{key};
				print $vstr . "\n";
			}
			else {
				return 1;
			}
		}
		else {
			return 1;
		}
	}
	return 0;
}


print "error!\n" if test_default;
print "error!\n" if test_multi;

