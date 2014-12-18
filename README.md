# Webackuper
==========
 
Description: Web backup automation tool
 
Autor: Tomas Hujer
 
 
## Installation
copy directory webackuper_plans into root folder, it will be contains your passwords for upload
 
## Main script
copy directory with file backup.sh into var or other folder from which it will be called
 
## Backup plans
- Change example backup plan in webackuper_plans directory
- change paths onto backuped project paths, setup right connections and passwords
- Comment out unused tasks
- Move plan into folder depended on delay when it may be backuped, for example every_three_days. You can create or rename folder as you mean, but you must specify the right folder to parameter on script calling in crontab.
 
## CRON
Insert task into crontab
30 2 */3 * * /var/bash/bash_backup/backup.sh every_three_days
 
Have fun
:-)
