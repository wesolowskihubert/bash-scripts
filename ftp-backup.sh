#!/bin/bash

# Requires NCFTP to be installed
# sudo apt-get install ncftp

# System Settings
DIRS="/bin /etc /home /var/local /usr/local/bin /usr/lib /var/www"
BACKUP=/tmp/backup.$$
NOW=$(date +"%Y-%m-%d")
INCFILE="/root/tar-inc-backup.dat"
DAY=$(date +"%a")
FULLBACKUP="Mon"

# MySQL Settings
MUSER="root"
MPASS="yourpassword"
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"

# FTP Settings 
FTPD="//backup-directory-on-ftp-server"
FTPU="ftp-username"
FTPP="ftp-password"
FTPS="ftp.server.address"
NCFTP="$(which ncftpput)"

# Send Email Address 
EMAILID="youremail@yourdomain.com"

# Backup our DPKG Software List 
dpkg --get-selections > /etc/installed-software-dpkg.log

# Start Backup 
[ ! -d $BACKUP ] && mkdir -p $BACKUP || :

# Check if we want to make a full or incremental backup 
if [ "$DAY" == "$FULLBACKUP" ]; then
  FTPD="//full-backups"
  FILE="MyServer-fs-full-$NOW.tar.gz"
  tar -zcvf $BACKUP/$FILE $DIRS
else
  i=$(date +"%Hh%Mm%Ss")
  FILE="MyServer-fs-incremental-$NOW-$i.tar.gz"
  tar -g $INCFILE -zcvf $BACKUP/$FILE $DIRS
fi

# Start the MySQL Database Backups 
# Get all the MySQL databases names
DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"
for db in $DBS
do
 FILE=$BACKUP/mysql-$db.gz
 $MYSQLDUMP --single-transaction -u $MUSER -h $MHOST -p$MPASS $db | $GZIP -9 > $FILE
done

# Check the Date for Old Files on FTP to Delete
REMDATE=$(date --date="35 days ago" +%Y-%m-%d)

# Start the FTP backup using ncftp
ncftp -u"$FTPU" -p"$FTPP" $FTPS<<EOF
cd $FTPD
cd $REMDATE
rm -rf *.*
cd ..
rmdir $REMDATE
mkdir $FTPD
mkdir $FTPD/$NOW
cd $FTPD/$NOW
lcd $BACKUP
mput *
quit
EOF

# Ckeck if ftp backup failed
if [ "$?" == "0" ]; then
 rm -f $BACKUP/*
 mail  -s "MYSERVER - BACKUP SUCCESSFUL" "$EMAILID"
else
 T=/tmp/backup.fail
 echo "Date: $(date)">$T
 echo "Hostname: $(hostname)" >>$T
 echo "Backup failed" >>$T
 mail  -s "MYSERVER - BACKUP FAILED" "$EMAILID" <$T
 rm -f $T
fi