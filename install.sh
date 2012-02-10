#!/bin/sh
# installs note

echo "Welcome to note `cat VERSION` installation."
echo "the install script will ask you a view questions,"
echo "make sure to answer them correctly!"
echo

/bin/echo -n "creating the note database..."
NAME="_note"
DBNAME="$USER$NAME"
echo "DBNAME=$DBNAME"
mysqladmin create $DBNAME
echo "done."
/bin/echo -n "creating the table structure using defaults..."
mysql $DBNAME < sql
echo "done."


