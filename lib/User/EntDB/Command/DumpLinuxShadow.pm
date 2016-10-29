
package User::EntDB::Command::DumpLinuxShadow;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::User;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;
	my $self = {
		'app' => $app,
		'cmdname' => 'dumplinuxshadow',
		'shorthelp' => "dumplinuxshadow dbfile: dump linux shadow\n",
		'longhelp' => "dumplinuxshadow dbfile\n"
		. " where: dbfile is the path to the desired database file\n"
	};

	bless $self,$class;
	$app->register($self);
	return $self;
}

sub do {
	my $self = shift;
	my $args = shift;
	my $fname = shift @{$args};
        if (!$fname) {
                print $self->{app}->help($self->{cmdname});
                return 0;
        }

	my $entdb = User::EntDB->new($fname);
	if(!$entdb) {
		print STDERR "error: $!\n";
		return 1;
	}

	$entdb->sethashfmt('linux');
	my $ulist = User::EntDB::User::getDBUserList($entdb);

        # Merging aux password data ...
	#
	# This should be done natively within EntDB, but we can't
	# currently ensure data integrity across types since 'aux'
	# data is not consistently built, so current method is to
	# keep aux things in the appropriate aux-local places. Not done
	# in EntDB::User directly since constructors don't have aux
	# logic.. and really 'shouldn't since they are intended to be
	# least-common-denominator.. Potential plan is to shift from
	# simply 'sethashfmt' in EntDB to e.g. 'setplatform'
	# which will handle all platform nits coherently and allow
	# pushing down this logic so that it is least-common-denominator
	# by default, and platform specific when required.

	our $auxl = $entdb->{lxauxents};
	our $auxh = {};

	# getaux:
	# Adds aux data to User::EntDB::User pwent field if it is available.

	my $getaux = sub { # caching partial iteration through aux list
		our ($auxl,$auxh);
		my $uobj = shift;
		my $name = $uobj->{pwent}->{name};

		my $found = $auxh->{$name};

		if(!$found) {
			while(my $i = shift @{$auxl}) {
				my $n = $i->{name};
				next unless $n; # hmm carp on bad data?
				$auxh->{$n} = $i;
				last if $n eq $name;
			}
			$found = $auxh->{$name};
		}
		if($found) {
			my $merge = {};
			%{$merge} = (%{$uobj->{pwent}},%{$found});
			$uobj->{pwent} = $merge;
		}
		return $uobj;
	};

	foreach my $user (@{$ulist}) {
		my $user = $getaux->($user);
		print $user->toLinuxShadow() . "\n";
	}
	return 0;
}

1;

