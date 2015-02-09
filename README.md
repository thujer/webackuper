# Webackuper
==========

Description: Web backup automation tool

Autor: Tomas Hujer


## Installation
copy directory webackuper_plans into root folder (security), it will be contains passwords for upload

## Main script
copy directory with file webackuper.sh into /var/www or other folder from which it will be called

## Backup plans
- Change example backup plan in webackuper_plans directory
- change paths onto backuped project paths, setup right connections and passwords
- Comment out unused tasks
- Move plan into folder which name is depended on timeplan when it may be backuped (for example every_three_days). You can create or rename folder as you mean, but you must specify the right folder to parameter on script calling in crontab.

## CRON
Insert task into crontab
30 2 */3 * * /var/bash/bash_backup/backup.sh every_three_days

## Autoremove old backups
Function RemoveOldFiles will processing deleting oldest backups. Default setting is deleting after 7 days.

## Transport backup to other server
/root/webackuper_plans (backup plans settings)
/var/www/webackuper (Webackuper script)
/var/log/backup (if You need old logs)
/var/backup (if You need backuped files)

Have fun
:-)

