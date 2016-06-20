
package User::EntDB::Command::DumpLinuxPasswd;

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
		'cmdname' => 'dumplinuxpasswd',
		'shorthelp' => "dumplinuxpasswd dbfile: dump linux passwd\n",
		'longhelp' => "dumplinuxpasswd dbfile\n"
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

	my $ulist = User::EntDB::User::getDBUserList($entdb);
	foreach my $user (@{$ulist}) {
		print $user->toLinuxPasswd() . "\n";
	}
	return 0;
}

1;

