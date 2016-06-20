
package User::EntDB::Command::DumpBSDPasswd;

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
		'cmdname' => 'dumpbsdpasswd',
		'shorthelp' => "dumpbsdpasswd dbfile: dump BSD master.passwd\n",
		'longhelp' => "dumpbsdpasswd dbfile\n"
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

	$entdb->sethashfmt('bsd');
	my $ulist = User::EntDB::User::getDBUserList($entdb);

	foreach my $user (@{$ulist}) {
		print $user->toBSDPasswd() . "\n";
	}
	return 0;
}

1;

