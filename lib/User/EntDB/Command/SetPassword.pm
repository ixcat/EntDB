
package User::EntDB::Command::SetPassword;

# TODO:
#
#  - hash verification for interactive non-admin use
#

use strict;
use warnings;

use POSIX qw(:termios_h);

use Crypt::PasswdMD5 qw(unix_md5_crypt);
use Crypt::Eksblowfish::Bcrypt qw(en_base64 bcrypt);

use User::EntDB;

# Terminal functions to disable echo w/o depending on a module
# see also: Perl Cookbook - 15.8. Using POSIX termios

my $fd_stdin;
my $term;
my $origflag;
my $noecho;

sub _prepecho;
sub _noecho;
sub _yesecho;

# Password/Hash Functions

sub _getpass; # read password

sub _mksalt; # generate bcrypt compatible salt (also used for md5)
sub _mkhashes; # { default => ..., md5 => ..., bcrypt => ... }
sub _setpass; # store hash to database

# Command functions

sub new;
sub do;

sub _prepecho {
	$fd_stdin = fileno(STDIN);
	$term = POSIX::Termios->new();
	$term->getattr($fd_stdin);
	$origflag = $term->getlflag();

	my $echo = ECHO | ECHOK | ICANON;

	$noecho = $origflag & ~$echo;
}

sub _noecho {
	$term->setlflag($noecho);
	$term->setcc(VTIME, 1);
	$term->setattr($fd_stdin, TCSANOW);
}

sub _yesecho {
	$term->setlflag($origflag);
	$term->setcc(VTIME, 1);
	$term->setattr($fd_stdin, TCSANOW);
}

# getpass - 
#
# fetch a password. expects terminal to be in non-echo mode
#
# BSD (UNIX) style:
#
# Changing local password for luser
# New Password:
# Retype New Password:
# Mismatch; try again, EOF to quit.
# (or nothing if OK)
#
# leenux style
#
# Changing password for user luser.
# New password: 
# BAD PASSWORD: it does not contain enough DIFFERENT characters
# BAD PASSWORD: is too simple
# Retype new password: 
# passwd: all authentication tokens updated successfully.
#
# we go with BSD style(ish), because it is a real unix, 
# and therefore civilized.
#

# to be deleted
sub _getpass_noeof {
	my ($pass, $pass2);
	while(1) { # FIXME: make != EOF & ^D work - but ^C takes in a pinch
		print "New Password: ";
		chomp($pass = <STDIN>);
		print "\nRetype New Password: ";
		chomp($pass2 = <STDIN>);
		return $pass if ($pass eq $pass2);
		print "\nMismatch; try again, ^C to quit.\n";
	}
}

sub _getpass {
	my ($pass, $pass2);
	while(1) {
		print "New Password: ";
		last unless defined(($pass = <STDIN>));

		print "\nRetype New Password: ";
		last unless defined(($pass2 = <STDIN>));

		if ($pass eq $pass2) {
			chomp $pass;
			return $pass;
		}

		print "\nMismatch; try again, EOF to quit.\n";
	}
	return undef; # EOF entered
}

sub _mksalt {
	my $salt = '';
	my $x = 0;
	while ($x < 16) { # XXX: rand() is not the best..
		$salt .= ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64];
		$x++;
	}
	$salt = en_base64($salt);
}

sub _mkhashes {
	my ($pass,$salt) = @_;

	$salt = _mksalt() unless defined $salt;

	my $md5hash = unix_md5_crypt($pass, $salt);
	my $bhash = bcrypt($pass, '$2a$08$' . $salt);

	return {
		'default' => $md5hash, # FIXME: hardcoded / non portable
		'md5' => $md5hash,
		'bcrypt' => $bhash
	};
}

sub _setpass {
	my ($file,$user,$hashes) = @_;

	my $entdb = User::EntDB->new($file) or return undef;

	return $entdb->storehashes({
		name => $user,
		hashes => $hashes
	});
}


sub new {
	my $class = shift;
	my $app = shift;

	my $longhelp = "setpassword db user [pass]\n\n"
	. "Set password 'pass' for 'user' in 'db'\n"
	. "\n"
	. "Interactively set a password for a user\n"
	;

	my $self = {
		'app' => $app,
		'cmdname' => 'setpassword',
		'shorthelp' => "setpassword db user [pass]: set a password\n",
		'longhelp' => $longhelp
	};

	bless $self,$class;
	$app->register($self);
	return $self;
}

sub do {
	my $self = shift;
	my $args = shift;
	my ($dbfile,$user,$pass) = @{$args};

	if (!($dbfile && $user)) {
		print $self->{app}->help($self->{cmdname});
                return 0;
	}

	if(!$pass) {
		_prepecho();
		_noecho();
		$pass = _getpass();
		return undef unless $pass; # ^D on input
		_yesecho();
		print "\n";
	}

	my $hashes = _mkhashes($pass);

	my $err = 0;
	$err = 1 if !defined(_setpass($dbfile,$user,$hashes));
	return $err;

}

1;

