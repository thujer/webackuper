#!/bin/bash
#
# (c) Tomas Hujer
#



# ------------------- TEST FREE SPACE ---------------------------
# Test free space on partitions
function testFreeSpace() {
    df -PkH | grep -vE '^Filesystem|tmpfs|cdrom|media' | awk '{ print $5 " " $6 }' | while read output;
    do
	usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1 )
	partition=$(echo $output | awk '{print $2}' )
	if [ $usep -ge $FREE_SPACE_THRESHOLD ]; then
	    echo "Na serveru dochazi volne misto na partition \"$partition ($usep%)\" on $(hostname) as on $(date)"
	fi
    done
}


# ------------------- CHECK FREE SPACE ---------------------------
# Test free space and send mail if is maller than THRESHOLD setting
function checkFreeSpace() {
    # Backup database and get output result
    RESULT_FREE_SPACE=$(testFreeSpace)

    # Get size of result
    RESULT_FREE_SPACE_SIZE=${#RESULT_FREE_SPACE}

    # If any result, than send result text by mail
    if(($RESULT_FREE_SPACE_SIZE > 0)); then
        echo "$RESULT_FREE_SPACE"
	mail -s $MAIL_SUBJECT $MAIL_RECIPIENTS <<< $RESULT_FREE_SPACE
    fi
}


# ---------------- FUNCTION DECLARATIONS ---------------
# Return Message if file size is smaller than $2 value
# $1 ... Real file size
# $2 ... Minimal file size
# $3 ... Message
function checkFileSize() {

    #echo "CheckFileSize: $1 $2"
    #exit

    if(("$1" < "$2"))
    then
	echo "$3"
    fi
}


# ---------------- DUMP DATABASE -----------------------
# Dump database to file, if any error or file is smaller, than echo message
function backupDB {

    # Backup directory exists check
    if [ ! -d $DB_BACKUP_DIR_LOCAL ]; then
        mkdir -p $DB_BACKUP_DIR_LOCAL
	echo "Vytvoren adresar pro lokalni zalohu databaze $DB_BACKUP_DIR_LOCAL" >> $LOG_FILE
    fi

    echo "Dumping database $DB_BACKUP_NAME to $DB_BACKUP_FILENAME_LOCAL ... " >> $LOG_FILE

    # mysqldump vraci chybovy status ve vystupu ID 3
    mysqldump -u $DB_BACKUP_USER -p$DB_BACKUP_PASS --databases $DB_BACKUP_NAME --routines 2>$LOG_FILE_ERROR | gzip -9 > $DB_BACKUP_FILENAME_LOCAL

    # Zjisti velikost chyboveho vystupu
    DB_ERROR_FILESIZE=$(stat -c%s "$LOG_FILE_ERROR")
    if(($DB_ERROR_FILESIZE > 0)); then
	EMAIL_MESSAGE="$EMAIL_MESSAGE Chyba při zálohování databáze $DB_BACKUP_NAME: `cat $LOG_FILE_ERROR`. "
	echo "$EMAIL_MESSAGE"  >> $LOG_FILE
    fi

    # Zjisti velikost souboru zalohy
    DB_BACKUP_FILESIZE=$(stat -c%s "$DB_BACKUP_FILENAME_LOCAL")
    if(($DB_BACKUP_FILESIZE < $DB_BACKUP_FILESIZE_MIN)); then
        EMAIL_MESSAGE="$EMAIL_MESSAGE Soubor zálohy databáze je podezřele malý: $DB_BACKUP_FILESIZE b. "
	echo "$EMAIL_MESSAGE" >> $LOG_FILE
    fi

    # If any result, than send result text by mail
    if [ "$EMAIL_MESSAGE" != "" ]; then
	mail -s $MAIL_SUBJECT $MAIL_RECIPIENTS <<< $EMAIL_MESSAGE
    else
	echo "Ok" >> $LOG_FILE
    fi
}


# ------------- BACKUP FILESYSTEM -------------------
function backupFilesystem() {

    echo "Compressing filesystem..." >> $LOG_FILE
    tar -pczPf $FS_BACKUP_TARGET_FILENAME $FS_BACKUP_SOURCE_DIR 2>$LOG_FILE_ERROR >> $LOG_FILE

    # Zjisti velikost chyboveho vystupu
    FS_ERROR_FILESIZE=$(stat -c%s "$LOG_FILE_ERROR")
    if(($FS_ERROR_FILESIZE > 0)); then
	EMAIL_MESSAGE="$EMAIL_MESSAGE Chyba při zalohovani filesystemu $FS_BACKUP_SOURCE_DIR `cat $LOG_FILE_ERROR` ! "
	echo "$EMAIL_MESSAGE" >> $LOG_FILE
    fi

    # Zjisti velikost souboru zalohy
    FS_BACKUP_FILESIZE=$(stat -c%s "$FS_BACKUP_TARGET_FILENAME")
    if(($FS_BACKUP_FILESIZE < $FS_BACKUP_FILESIZE_MIN)); then
        EMAIL_MESSAGE="$EMAIL_MESSAGE Soubor zálohy filesystemu je podezřele malý: $FS_BACKUP_FILESIZE bytes. "
	echo "$EMAIL_MESSAGE" >> $LOG_FILE
    fi

    # If any result, than send result text by mail
    if [ "$EMAIL_MESSAGE" != "" ]; then
	mail -s $MAIL_SUBJECT $MAIL_RECIPIENTS <<< $EMAIL_MESSAGE
    else
	echo "Ok" >> $LOG_FILE
    fi
}


# --------------- REMOVE OLD FILES ----------------------
function removeOldFiles() {
    echo "Removing old files..." >> $LOG_FILE
    find /var/backup/$DOMAIN/ -maxdepth 1 -type f -mtime +7 -exec rm -rf {} \; 2>&1 >> $LOG_FILE
}


# ------------- UPLOAD TO NAS/FTP ------------------
function uploadBackupToNASByFTP() {
    echo 'Uploading to NAS by FTP ...' >> $LOG_FILE

    lftp -d $FTP_HOST -u $FTP_USER,$FTP_PASS -e "put $FS_BACKUP_TARGET_FILENAME $FTP_REMOTE_DIR/$FS_BACKUP_TARGET_FILENAME; put $DB_BACKUP_FILENAME_LOCAL $FTP_REMOTE_DIR/$DB_BACKUP_FILENAME_LOCAL; quit"
}


# ------------- UPLOAD TO NAS/RSYNC ------------------
function rsyncToNASbySSH() {
    echo 'Uploading to NAS by RSYNC ...' >> $LOG_FILE
    rsync -a --password-file=$RSYNC_PASS_FILE $FS_BACKUP_TARGET_DIR/ $RSYNC_TARGET_DIR 2>$LOG_FILE_ERROR >> $LOG_FILE

    # Zjisti velikost chyboveho vystupu
    RSYNC_ERROR_FILESIZE=$(stat -c%s "$LOG_FILE_ERROR")
    if(($RSYNC_ERROR_FILESIZE > 0)); then
	EMAIL_MESSAGE="Chyba při odesilani zaloh pres rsync: `cat $LOG_FILE_ERROR`, zdrojovy adresar: $FS_BACKUP_TARGET_DIR ! "
	echo "$EMAIL_MESSAGE" >> $LOG_FILE
    fi

    # If any result, than send result text by mail
    if [ "$EMAIL_MESSAGE" != "" ]; then
	mail -s $MAIL_SUBJECT $MAIL_RECIPIENTS <<< $EMAIL_MESSAGE
    else
	echo "Ok" >> $LOG_FILE
    fi
}


# ------------- FINISH -------------------
function done() {
    echo "Finished." >> $LOG_FILE
}


if [ "$1" == "" ]; then
    echo "Parametr musi byt typ casoveho udaje - podadresar s casovym ID, napr. daily nebo every_three_days"
    exit
fi


for CONFIG_FILE in /root/backup_cron/$1/*.cfg; do

    EMAIL_MESSAGE=""

    if [ -f $CONFIG_FILE ]; then
	# Load config file
	source $CONFIG_FILE
	echo "Processing $CONFIG_FILE file.." >> $LOG_FILE

	if [ ! -f $LOG_DIR ]; then
	    mkdir -p $LOG_DIR
	    echo "Vytvoren adresar pro log soubory $LOG_DIR" >> $LOG_FILE
	fi

	# Check disk free space
	# TODO: if free space is smaller than critical, dont store backup
	checkFreeSpace

	# Dump database with check errors
	backupDB

	# Backup filesystem, if target archive is smaller, send warning mail
	backupFilesystem

	# Upload
	#uploadBackupToNASByFTP
	rsyncToNASbySSH

	# Remove old backups
	removeOldFiles

    fi
done

