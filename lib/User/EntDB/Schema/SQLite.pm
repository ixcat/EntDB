package User::EntDB::Schema::SQLite;

# User::EntDB::Schema::SQLite
# ===========================
#
# SQLite entdb passwd(5)/group(5) DB schema -
#
# intended to mimic 'native' flatfile behavior as closely as possible
# see notes in <DATA> for thoughts/rationale here.
#
# functions might be 'nicer' if this is just a simple wrapper around 
# dumping a flat file stored with the package.
#
# $Id$
#

use strict;
use warnings;

sub getSchema;
sub getTestData;
sub getNotes;


sub getSchema{

return <<'__EOSCHEMA'
--
-- User/Group Schema (SQLite)
--
-- Intended to support 1:1 storage of /etc/{passwd,group},
-- quirks included.
--
-- Some mangling to support relational model required.
--
-- $Id$
--

-- users: user 'definitions' (e.g. 1:1 /etc/passwd data)

create table users(
	uname text not null, 
	passwd text default '*',
	uid integer not null,
	gid integer not null,
	gecos text,
	dir text default '/',
	shell text default '/sbin/nologin',
	foreign key(gid) references groups(gid),
	primary key (uname,uid)
);

-- password hash type dispatch

create table hash_cfg (
	platform text not null primary key,
	type text not null
);

insert into hash_cfg values ('default','default');
insert into hash_cfg values ('linux','md5');
insert into hash_cfg values ('bsd','bcrypt');
insert into hash_cfg values ('adjunct','md5');

-- the 'default' password hash table - 
-- TODO:
--  - clarify purpose : 
--    - ingest x vs *locktag* or..?
--    - operational concerns e.g. 1st load vs ongoing ops
--      like, if system is configured for md5, how does this get populated,
--      and then how is default updated / what is stored there?a
--
-- other tables can be used for differing formats, etc,
-- but should follow same table structure and be named hashes_<type>
-- for use in client programs.

create table hashes_default (
	uname text not null primary key,
	passwd text not null default '*'
);

create table hashes_md5 (
	uname text not null primary key,
	passwd text not null default '*'
);

create table hashes_bcrypt (
	uname text not null primary key,
	passwd text not null default '*' 
);

-- groups: group 'definitions' (e.g. 1:1 /etc/group fields 1-2)
--    XXX: we do not support group passwords, since they are not usually used 

create table groups(
	gname text not null, 
	gid integer not null, 
	primary key (gname,gid)
);

-- aux_groups: group 'members' (e.g. 1:1 /etc/group field 4)

create table aux_groups(
	gid integer,
	uname text,
	foreign key(gid) references groups(gid),
	foreign key(uname) references users(uname),
	primary key (gid,uname)
);

--
-- etc_group:
--
-- returns multiple gname:gid:uname records per group,
-- summing to the total of the contents of all auxilliary groups - e.g.:
--
-- group1:gid1:uname1
-- group1:gid1:uname2
-- group1:gid1:...
-- group1:gid1:unameN
-- ...
-- groupN:gidN:uname1
-- groupN:gidN:...
-- groupN:gidN:unameN
--
-- Groups are in GID sequential order, and group members are be returned 
-- in order of insert. It should be noted that this inherently implies 
-- groups are not currently returned in order of their definition.
--
-- XXX: could do this potentially with group by?
--
-- Of note - this only reports auxiliary group membership - 
-- e.g. it mimics the /etc/group file functionality.
-- primary groups are stored in the passwd table or can be retrieved
-- in combination with auxilliary groups via the 'user_group_map' view
-- which follows.
--
-- XXX: This query is a bit odd/iffy..
--    Without the rowid selection, aux_groups are displayed in reverse
--    with respect to their insert sequence, yielding a reversal when
--    groups are read back, causing dumps to mismatch w/r/t loads,
--    which is undesired for the basic 1:1 load/dump idea of functionality.
--    for some strange reason, simply adding the rowid select fixes this.
--    needless to say this could be a bit undefined and potentially
--    better done in some other way..
--

create view etc_group as
select gname,gid,uname from (
select
	ag.rowid as rowid,
        g.gname as gname,
        g.gid as gid,
        ag.uname as uname
from
        groups g,
        aux_groups ag
where
        g.gid = ag.gid
union
select
	-1 as rowid,
        gname,
        gid,
        null as uname
from
        groups
where
        gid
not in (
        select distinct(gid)
        from aux_groups
)
order by
        g.gid asc
)
;

-- user_group_map:
--
-- returns multiple user:group records per user, 
-- summing to the total of all of a users aux groups - e.g.:
--
-- user:pgid:aux_gid1
-- user:pgid:aux_gid2
-- user:pgid:aux_gid...
-- user:pgid:aux_gidN
--
-- such that interating through the results should allow building
-- a list of a user's aux groups.
--
-- is a 2 part query of complex queries -
-- 1st part expands users having auxilliary groups
-- 2nd part returns remaining users without auxilliary groups.
--

create view user_group_map as
select 	distinct(nu.uname) uname,
	nu.uid uid,
	nu.gid gid,
	nu.pgname pgname,
	ag.gid agid,
	g.gname agname
from 
	groups g,
	aux_groups ag,
	(
		select 
			u.uname uname,
			u.uid uid,
			u.gid gid,
			g.gname pgname
		from 
			users u,
			groups g
		where
			u.gid = g.gid 
	) nu
where
	nu.uname = ag.uname
and
	g.gid = ag.gid
union
select  distinct(nu.uname) uname,
	nu.uid uid,
	nu.gid gid,
	nu.pgname pgname,
	NULL,
	NULL
from
	        (
                select
                        u.uname uname,
                        u.uid uid,
                        u.gid gid,
                        g.gname pgname
                from
                        users u,
                        groups g
                where
                        u.gid = g.gid
        ) nu
where 
	uname
not in (
	select distinct(uname)
	from aux_groups
)
order by
nu.uname 
asc;


--
-- netgroup storage
--
-- Base data, including references to subgroups -
-- It is not possible to create a fully expanded SQL view without
-- a stored procedure language, and therefore SQLite, since 
-- expansion of the groups would require recursion.
--
-- Conceivably a trigger-based mechanism could build such a table
-- upon insertion, however this is not currently implemented.
-- Clients should instead perform netgroup expansion via subqueries 
-- where needed.
--

create table netgrent (
	netgroup text not null,
	ref text default null,
	host text default null,
	user text default null,
	domain text default null,
	primary key (netgroup,ref,host,user,domain)
);

--
-- /etc/mail/aliases storage
--
-- simple key/value map table to store user->recipient mappings
-- key is not unique and data is unstructured since there is 1:M mapping
--

create table aliases_kv (
	key text,
	val text
);

create view aliases as
select 
	aliases_kv.key as user,
	aliases_kv.val as recipient
from aliases_kv;

__EOSCHEMA
;

}



sub getTestData {

return <<'__EOTEST'
--
-- user/group test data
--
-- $Id$
-- 
-- .. allowing 'sloppy' multi-uid/gid entries, 
--    but operating in order of appearance, 
--    mimicing file-based behavior
-- 
-- hmm: probably need to populate aux_groups via insert-select hybrid -
--   for the 'best' behavior.. e.g. insert into aux_groups where
--    uid is from 1st logname match in select from users by logname ..
--   alternately, populate groups with string tokens and compute on
--   select time.. which is actually the most correct
-- 


-- v7: uname, passwd, uid, gid, gecos, dir, shell

insert into users (uname, uid, gid) values ('u1',1,20);
insert into users (uname, uid, gid) values ('u1',2,20);
insert into users (uname, uid, gid) values ('u2',2,20);
insert into users (uname, uid, gid) values ('u2',3,20);

insert into groups values ('wheel',0);
insert into groups values ('users',10);
insert into groups values ('staff',20);

insert into aux_groups values (0,'u1');
insert into aux_groups values (10,'u1');
insert into aux_groups values (0,'u2');

select * from user_group_map;

delete from users;
delete from groups;
delete from aux_groups;

-- now, 'clean' data

insert into users (uname, uid, gid) values ('u1',1,20);
insert into users (uname, uid, gid) values ('u2',2,20);

insert into groups values ('wheel',0);
insert into groups values ('users',10);
insert into groups values ('staff',20);

insert into aux_groups values (0,'u1');
insert into aux_groups values (10,'u1');
insert into aux_groups values (0,'u2');

select * from user_group_map;

insert into netgrent values ( 'servers', 'NULL', 'server1', 'NULL', 'NULL');
insert into netgrent values ( 'clients', 'NULL', 'cli1', 'NULL', 'NULL');
insert into netgrent values ( 'clients', 'NULL', 'cli2', 'NULL', 'NULL');
insert into netgrent values ( 'allhosts', 'servers', 'NULL', 'NULL', 'NULL');
insert into netgrent values ( 'allhosts', 'clients', 'NULL', 'NULL', 'NULL');
insert into netgrent values ( 'admins', 'NULL', 'NULL', 'u1', 'NULL');
insert into netgrent values ( 'admins', 'NULL', 'NULL', 'u2', 'NULL');
insert into netgrent values ( 'admins', 'users', 'NULL', 'NULL', 'NULL');
insert into netgrent values ( 'admins', 'NULL', 'NULL', 'u1', 'NULL');
insert into netgrent values ( 'admins', 'allusers', 'NULL', 'NULL', 'NULL');
insert into netgrent values ( 'admins', 'admins', 'NULL', 'NULL', 'NULL');
insert into netgrent values ( 'admins', 'guests', 'NULL', 'NULL', 'NULL');

delete from users;
delete from groups;
delete from aux_groups;

__EOTEST
;

}

1;
__DATA__
Notes concerning schema implementation
======================================

common unix function behavior on flatfiles
------------------------------------------

The entdb utility and database schema should attempt to preserve
most traditional unix semantics where possible.

The following key functions and their behavior are documented here
as a reference:

getpwent - iterate sequentially over records in pwent
getpwnam - get 1st for name string
getpwuid - get 1st for uid .. hmm nismaps? 
  ... (built by getpwent? keyed sequentially?)

getgrent - sequential reading
getgrnam - sequential search for name
getgruid - sequential search for uid

it should be noted that entdb databases built from NIS or other
directory-based services might result in differing record storage
than the above behavior would suggest with respect to the input
source files used to create the database -

For example, if using entdb to distill existing NIS entries:

  1) NIS Input files are stored in expected order
  2) NIS Maps are built using normal non-entdb procedures, 
     resulting in different data sequence in above system calls due to
     database indexing methods in the data storage for the map
  3) These differing sequences are stored into the resuling entdb.

As the above illustrates, the unexpected sequence of results in the
generated entdb database is not a bug in entdb itself but instead
simply a reflection of the upstream source; If original input
sequences are desired, the input data should be configured into the
traditional flat-file locations on the system used to build the
entdb database and then re-run.

Primary vs Auxiliary Groups
---------------------------

From 4.3BSD su(1):

  If no userid is specified, ``root'' is assumed.  Only users in the
  ``wheel'' group (group 0) can su to ``root'', even with the root
  password.  To remind the super-user of his responsibilities, the Shell
  substitutes `#' for its usual prompt.

with bin/su.c using getgrgid(3) calls to ascertain gid 0 if such calls
are successful.

OpenBSD (2.4ish) updates the page to read:

  If group 0 (normally ``wheel'') has users listed then only those users
  can su to ``root''.  It is not sufficient to change a user's /etc/passwd
  entry to add them to the ``wheel'' group; they must explicitly be listed
  in /etc/group.  If no one is in the ``wheel'' group, it is ignored, and
  anyone who knows the root password is permitted to su to ``root''.

Which documents the code behavior previously extant in 4.3BSD su(1).

Therefore, 
given the historical importance of the 4.3BSD release, and the
early and appearance of 4.3BSD's su(1) behavior consistent up
to the present day, and the importance of the su(1) utility to
system operation, the differentiation of primary vs auxiliary
groups is and has been an important facet of UNIX system operation
which should be adhered to in this database model.

Todo: track down and document duplicate uid/gid behavior history - notes:

 - OpenBSD 5.8 (modern reference):
   - getgrent(3) ob58 states:
     Identical group names or group GIDs may result in undefined behavior.
   - no similar message in getpwent
 - Couldn't find origin of 'toor' account as configured in freebsd -
   ( no 4.2/4.3BSD /etc/passwd available at time of writing to cross-check )

