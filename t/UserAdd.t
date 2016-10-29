#! /bin/sh

# test of useradd command 

./bin/entdb useradd /var/yp/ent/db \
	-d /home/dude \
	-c dude \
	-g users -G wheel,audio \
	-u 1005 -s /bin/sh \
	dude

./bin/entdb setpassword /var/yp/ent/db dude

./bin/entdb dumplinuxpasswd /var/yp/ent/db |grep dude
./bin/entdb dumplinuxshadow /var/yp/ent/db |grep dude
./bin/entdb dumpgroup /var/yp/ent/db | grep dude

printf "delete from users where name='dude';\n" |sqlite3 /var/yp/ent/db
printf "delete from hashes_bcrypt where name='dude';\n" |sqlite3 /var/yp/ent/db
printf "delete from hashes_default where name='dude';\n" |sqlite3 /var/yp/ent/db
printf "delete from hashes_md5 where name='dude';\n" |sqlite3 /var/yp/ent/db
printf "delete from aux_groups where name='dude';\n" |sqlite3 /var/yp/ent/db

