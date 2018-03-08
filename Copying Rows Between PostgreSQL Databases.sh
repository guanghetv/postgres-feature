#Copying Rows Between PostgreSQL Databases

PGPASSWORD=Yangcong345 psql -h 10.8.8.8 -U postgres mydb -c \
"\copy stage TO stdout" | \
PGPASSWORD=Yangcong345 psql -h 10.8.8.8 -U postgres mydb -c "\copy copy_table FROM STDIN"


# https://www.endpoint.com/blog/2013/11/21/copying-rows-between-postgresql