/usr/local/mysql/bin/mysql -u root -p flight_management <<EOF
source SQL/db.sql;
source SQL/script.sql;
EOF