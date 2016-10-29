#
# useradd command loosely modeled around sysv/linux style useradd
# which is similar to *Free*BSD adduser - potentially will shift
# towards FreeBSD-like 'pw' command, since this seems to be the
# best utility suite for these things, however, for now, only basic
# account creation is needed so this should do.
#
# various system command synopsis output is below for reference.
#
# Notes:
#
#  - not handling 'aux' data for linux shadow, bsd master.passwd
#

package User::EntDB::Command::UserAdd;

use strict;
use warnings;

use Getopt::Std;

use User::EntDB;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;
	my $shorthelp = "useradd db -d d -c c -g g -G g,g -u u -s s user:"
		. " add a user\n";

	my $longhelp = "useradd db -d /home/dir"
		. " -c comment"
		. " -g logingroup\n\t"
		. " -G auxgroup,..."
		. " -u uid"
		. " -s shell"
		. " user\n"
		. "\n"
		. "all fields required - set passwords with setpassword"
		. "\n"
	;

	my $self = {
		'app' => $app,
		'cmdname' => 'useradd',
		'shorthelp' => $shorthelp,
		'longhelp' => $longhelp
	};

	bless $self,$class;
	$app->register($self);
	return $self;
}

sub do {
	my $self = shift;
	my $args = shift;
	my $fname = shift @{$args};
	my $oldv = undef;
	my $opts = {};
	my $pwent = {}; # spoofed struct
	my $user = undef;
	my $db = undef;

	my $doerr = sub {
		print $self->{app}->help($self->{cmdname});
		return undef;
	};

	return $doerr->() unless $fname;

	$oldv = [ @ARGV ];

	getopts('d:c:g:G:u:s:', $opts);
	$user = shift @ARGV;

	@ARGV = $oldv;

	return $doerr->() unless $user;
	$pwent->{name} = $user;
	$pwent->{passwd} = '*uninitialized*';

	my $optmap = {
		'd' => 'dir',
		'c' => 'gecos',
		'g' => 'gid',
		'G' => 'auxgroups',
		'u' => 'uid',
		's' => 'shell',
	};

	foreach my $opt (keys %{$optmap}) {
		my $arg = $opts->{$opt};
		return $doerr->() if(!defined($arg));
		$pwent->{$optmap->{$opt}} = $arg;
	}

	$db = User::EntDB->new($fname) or return undef;

	# lookup gids, gen auxgroup sql if needed

	my $ngrp = 0;
	my $tmpgr = [];
	$pwent->{auxgroups} = [ split( ',', $pwent->{auxgroups}) ];

	foreach my $gstr (($pwent->{gid}, @{$pwent->{auxgroups}} )) {
		if($gstr !~ m/^d+$/) {
			my $grp = $db->getgrnam($gstr);
			$gstr = $grp->{gid};
		}
		if ($ngrp == 0) {
			$pwent->{gid} = $gstr;
		}
		else {
			push @{$tmpgr}, $gstr;
		}
		$ngrp++;
	}
	$pwent->{auxgroups} = $tmpgr;

	my $u = User::EntDB::User::fromPrec($pwent);

 	my $sqlist = User::EntDB::User::convertUserListToSQL([$u]);

	$db->begintxn();

	foreach my $sql (@{$sqlist}) {
		$db->do($sql);
	}

	# XXX hack.. aux group insertion should really go somewhere else -
	# but in ::User or ::Group object, and how? herm.

	foreach my $gid (@{$pwent->{auxgroups}}) {
                my $sql = "insert into aux_groups values ("
			. $gid
			. ",'" . $pwent->{name} . "'"
			. ");\n"
		;
		$db->do($sql);
	}
	$db->endtxn();

	return 0;
}


1;

__DATA__
# 20161025
# FreeBSD:
     adduser [-CDENShq] [-G groups] [-L login_class] [-M mode] [-d partition]
             [-f file] [-g login_group] [-k dotdir] [-m message_file]
             [-s shell] [-u uid_start] [-w type]
# OpenBSD:
     useradd -D [-b base-directory] [-e expiry-time] [-f inactive-time]
             [-g gid | name | =uid] [-k skel-directory] [-L login-class]
             [-r low..high] [-s shell]
     useradd [-mov] [-b base-directory] [-c comment] [-d home-directory]
             [-e expiry-time] [-f inactive-time]
             [-G secondary-group[,group,...]] [-g gid | name | =uid]
             [-k skel-directory] [-L login-class] [-p password] [-r low..high]
             [-s shell] [-u uid] user
# Linux:
Usage: useradd [options] LOGIN
       useradd -D
       useradd -D [options]

Options:
  -b, --base-dir BASE_DIR       base directory for the home directory of the
                                new account
  -c, --comment COMMENT         GECOS field of the new account
  -d, --home-dir HOME_DIR       home directory of the new account
  -D, --defaults                print or change default useradd configuration
  -e, --expiredate EXPIRE_DATE  expiration date of the new account
  -f, --inactive INACTIVE       password inactivity period of the new account
  -g, --gid GROUP               name or ID of the primary group of the new
                                account
  -G, --groups GROUPS           list of supplementary groups of the new
                                account
  -h, --help                    display this help message and exit
  -k, --skel SKEL_DIR           use this alternative skeleton directory
  -K, --key KEY=VALUE           override /etc/login.defs defaults
  -l, --no-log-init             do not add the user to the lastlog and
                                faillog databases
  -m, --create-home             create the user's home directory
  -M, --no-create-home          do not create the user's home directory
  -N, --no-user-group           do not create a group with the same name as
                                the user
  -o, --non-unique              allow to create users with duplicate
                                (non-unique) UID
  -p, --password PASSWORD       encrypted password of the new account
  -r, --system                  create a system account
  -R, --root CHROOT_DIR         directory to chroot into
  -s, --shell SHELL             login shell of the new account
  -u, --uid UID                 user ID of the new account
  -U, --user-group              create a group with the same name as the user
  -Z, --selinux-user SEUSER     use a specific SEUSER for the SELinux user mapping
# Solaris:
     useradd [-c comment] [-d dir] [-e expire]  [-f inactive]  [-
     g group]  [  -G group  [  , group...]] [ -m [-k skel_dir]] [
     -u uid  [-o]]  [-s shell]  [-A  authorization   [,authoriza-
     tion...]]  [-P profile  [,profile...]] [-R role  [,role...]]
     [-p projname] login

     useradd  -D  [-b base_dir]  [-e expire]   [-f inactive]   [-
     g group] [-p projname]

