
package User::EntDB::Command::DumpPasswdAdjunct;

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
		'cmdname' => 'dumppasswdadjunct',
		'shorthelp' => "dumppasswdadjunct dbfile: dump linux shadow\n",
		'longhelp' => "dumppasswdadjunct dbfile\n"
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

	foreach my $user (@{$ulist}) {
		print $user->toPasswdAdjunct() . "\n";
	}
	return 0;
}

1;

