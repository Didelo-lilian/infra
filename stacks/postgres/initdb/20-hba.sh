#!/bin/sh
# Runs once, after 10-semaphore.sql. The superuser has a password because the image insists on one, but nothing
# connects as the superuser except `docker exec` over the socket: reject it from the network, whatever the password.
# pg_hba.conf is read from the top and the image appends "host all all all scram-sha-256", so the line goes first.
sed -i '1i host all postgres all reject' "$PGDATA/pg_hba.conf"
