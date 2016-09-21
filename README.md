mongodb fast deploy image
====================

based on:
https://hub.docker.com/_/mongo/

scripts copy from:
https://github.com/tutumcloud/mongodb 
(apache 2.0 license)

fast run
---------------

    curl https://raw.githubusercontent.com/GongT/service-mongodb/master/fast_install.sh | sh

to change database save path:

    export DATABASE_PATH="/data/database"
    curl https://raw.githubusercontent.com/GongT/service-mongodb/master/fast_install.sh | sh


MongoDB version
---------------
mongo:latest (3.2)

Usage
-----
run script `build_start.sh`

admin user is "admin"   
default password is "password"

you can update these and create other user after service running.

run `build.sh db_path ` to change default database save path    
default database files save at `pwd`/database
