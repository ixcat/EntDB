
package User::Netgroup;

use strict;
use warnings;

# User::Netgroup: 
#
# Currently:
#
#   A somewhat stream-oriented procedural netgroup parser in the 
#   function 'nextnetgrent' which returns a hash:
#
#     $ng = {
#	'netgroup' => 'name string',
#	'entries' => [
#		{
#			'ref' => string,
#			'host' => string,
#			'user' => string,
#			'domain' => string
#		},
#		...
#       ]
#     };
#
#   for each netgroup, or otherwise undef if no further records exist
#   or the netgroup file does not exist.
#
# EVENTUALLY:
#
# A thin procedural package providing pure perl netgroup functions
# 
# Implementation Note:
#
# Netgroups unfortunately do not have:
#
#   - clean iteration method
#   - clear/direct 'struct' for data
#
# So we:
#
#   - parse directly here
#   - create our own type, a hash of ref, host, user and domain strings
#
# and attempt to emulate low-level api as directly as possible, with
# the main useful additions of:
#
#   - calling 'setnetgrent()' with no arguments rewinds entire file
#     and resets internal state variables.
#   - a 'nextnetgrent()' function allows iteration over the entire dataset
#
# which allows full and naieve traversal over the entire netgroup
# database.  Since this is not a native capability, and there is
# no 'netgrent' struct, the package is named 'Netgroup' rather than
# following the pattern of User::pwent, etc. which wrap native calls
# and mimic native structs.
#
# Unfortunately, this also implies we parse the /etc/netgroup file directly
# and do not use e.g. DBM calls or similar to perform traversal, though
# concievably this could be done using native DBM and other methods at
# a system level without needing to directly parse the netgroup file in perl.
#
# Setting the package global NETGROUPFILE prior to initial use can be used
# to parse other locations than /etc/netgroup.
#
# Since this module was designed to mimic the native calls as much as possible,
# package-level global variables are used and so the code should not be
# considered thread safe.
#

sub nextnetgrent;
sub getnetgrent;
sub innetgr;
sub setnetgrent;
sub endnetgrent;

our $NETGROUPFILE = '/etc/netgroup';

my $ngfh = undef;

sub nextnetgrent {

	my ($ng,$data,$name,$memb);

	$ng = {};
	$data = '';
	$name = undef;
	$memb = undef;

	if(!$ngfh) {
		if(!open($ngfh, '<', $NETGROUPFILE )) {
			$ngfh = undef; # is glob if file doesn't exist
			return $ngfh;
		}
	}

	while(<$ngfh>) {
		next if $_ =~ m:^\s*#:;
		chomp;

		if ( $_ =~ m:\s*\\: ) { 		# find full entries
			$_ =~ s:\s*\\$: :;
			$data .= $_;
			next;
		}
		else {
			$data .= $_;
		}

		$memb = [ split /\s+/, $data ];		# and parse them

		if(scalar $memb > 1) {

			$name = shift @{$memb};
			$ng = {
				'netgroup' => $name,
				'entries' => []
			};

			foreach my $m (@{$memb}) {

				my ($r,$h,$u,$d) = undef;

				if ( $m =~ m:\(.*?,.*?,.*?\): ) { # triple type

					$m =~ s:(\(|\))::g; # zap '()'

					($h,$u,$d) = split /,/, $m;

					$h = undef if defined $h && $h eq '';
					$u = undef if defined $u && $u eq '';
					$d = undef if defined $d && $d eq '';

				}
				else {			# xref type
					$r = $m;
				}

				push @{$ng->{entries}}, {
					'ref' => $r,
					'host' => $h,
					'user' => $u,
					'domain' => $d
				};
			}
			return $ng;
		}
		return $ng; # hmm: empty groups possible?
	}
	return undef; # EOF
}

1;
__DATA__
# some example test data
servers (server1,,)
clients \
(cli1,,) \
(cli2,,)
allhosts servers clients
admins \
(,user1,) \
(,user2,) \
guests \
(,guest1,) \
(,guest2,) \
allusers admins guests
