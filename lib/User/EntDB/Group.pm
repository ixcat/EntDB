
# User::EntDB::Group
#
# group representation class
# partial-wrapper around User::grent currently
#
# $Id$

package User::EntDB::Group;

use strict;
use warnings;

use User::grent;

sub new;
sub fromGrec;
sub fromGrent;

sub toSQLite;
sub toGroup; 

sub getDBGroupList;
sub getSysGroupList;

sub loadAllGroupsFromSystem;

sub convertGroupListToSQL;

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;
	return $self;
}

sub fromGrec { # construct from k:v hash of User::grent-like attributes
	my $self = User::EntDB::Group->new();
	my $grec = shift;
	$self->{grent} = $grec;
	return $self;
}

sub fromGrent { # construct from actual User::grent objects
	my $self = User::EntDB::Group->new();
	my $grent = shift;
	my $grec = {};

	$grec->{name} = $grent->name();
	$grec->{gid} = $grent->gid();
	$grec->{members} = $grent->members();

	$self->{grent} = $grec;

	return $self;
}

# create an sqlite insert statement -
# specifically *not* using DBI here to allow for 'text output' case.

sub toSQLite {

	my $self = shift;
	my $grent = $self->{grent};

	my ($name,$gid,$members);

	$name = $grent->{name};
	$gid = $grent->{gid};
	$members = $grent->{members};

	my $q = "insert into groups values ("
		. "'" . $name . "'"
		. "," . $gid . ""
	. ");\n";

	foreach my $u (@{$members}) {
		$q .= "insert into aux_groups values ("
		. $gid
		. ",'" . $u . "'"
		. ");\n";
	}
	return $q;
}

sub toGroup { # return /etc/group line for given entry
	my $self = shift;

	my $g = $self->{grent};
	my $gm = $g->{members};

	my $r = $g->{name}
		. ":*" # passwd - not implemented
		. ':' . $g->{gid}
		. ':';

	if(@{$gm}) {
		foreach(@{$gm}) {
			$r .= "$_,";
		}
		chop $r;
	}
	return $r;
}

sub getDBGroupList { # static. returns arrray of objs from DB
	my $entdb = shift;

	my $glist = [];

	while(my $g = $entdb->getgrent()) {
		push @{$glist}, User::EntDB::Group::fromGrec($g);
	}
	return $glist;
}

sub getSysGroupList { # static. returns arrayref of objs from system
	my $glist = [];
	while (my $rec = User::grent::getgrent()) {
		my $g = User::EntDB::Group::fromGrent($rec);
		push @{$glist}, $g;
	}
	return $glist;
}

sub convertGroupListToSQL { # generates array of SQL cmds to build group tables
	my $glist = shift;
	my $sqlist = [];
	foreach my $u (@{$glist}) {
		my $stmnt = $u->toSQLite();
		push @{$sqlist}, $stmnt;
	}

	return $sqlist;
}

sub loadAllGroupsFromSystem { # full getent->sqlite db conversion of all users
	my $fname = shift;

	return undef unless $fname;

	my $entdb = User::EntDB->new($fname);
	my $glist = User::EntDB::Group::getSysGroupList();
	my $sqlist = User::EntDB::Group::convertGroupListToSQL($glist);

	$entdb->begintxn();
	foreach my $groupsql (@{$sqlist}) {
		$entdb->do($groupsql);
	}
	$entdb->endtxn();
}

1;
