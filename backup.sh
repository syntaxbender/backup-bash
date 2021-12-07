#!/bin/bash
script_file=$(readlink -f "$0")
script_path=$(dirname $script_file)
istarinstalled=$(tar --version | head -n 1 | awk '{print $1}')
currentuser=$(whoami)
ischoosed=0
create_backup(){ # -r parameter run script
	if [[ ! -f "${script_path}/data/config.dat" ]]; then
		echo "Öncelikle -e parametresi kullanarak uygulamayı yapılandırınız."
		exit 1
	fi
	backup_store_dir=$(sed -n 's/backup_store_dir "\(.*\)"/\1/p' "${script_path}/data/config.dat")
	backup_dir=$(sed -n 's/backup_dir "\(.*\)"/\1/p' "${script_path}/data/config.dat")
	backup_count=$(sed -n 's/backup_count "\(.*\)"/\1/p' "${script_path}/data/config.dat")
	last_backups=$(cat "${script_path}/data/last_backups.dat")

	if [[ ! -d "$backup_store_dir" || ! -d "$backup_dir" || ! -r "$backup_dir" || ! -w "$backup_store_dir"  ]]; then
		echo "Öncelikle backup dizinlerini ayarlayınız ve dizinlerin varolduğundan ve yazılabilir olduğundan emin olunuz."
		exit 1
	fi

	for (( i=$(echo "${last_backups}" | wc -l); i>=backup_count; i-- ))
	do
		rm "${backup_store_dir}/$(sed -n "1p" "${script_path}/data/last_backups.dat")" && sed -i "1d" "${script_path}/data/last_backups.dat"
	done

	backup_fname="backup_$(date +"%Y.%m.%d_%T").tar.gz"
	tar -czvf "${backup_store_dir}/${backup_fname}" $backup_dir && echo "${backup_fname}" >> "${script_path}/data/last_backups.dat"
	chmod 600 "${backup_store_dir}/${backup_fname}"
}
edit_cron(){ # -e parameter edit cron
	echo "Hangi dosyaların yedeği alınacak? Lütfen bir dizin belirtiniz."
	read -r backup_dir
	echo "Yedekler nerede saklanacak? Lütfen bir dizin belirtiniz."
	read -r backup_store_dir
	if [[ ! -d "$backup_store_dir" || ! -d "$backup_dir" || ! -r "$backup_dir" || ! -w "$backup_store_dir"  ]]; then
		echo "Tanımlamak istediğiniz dizinlerin varolduğundan ve yazılabilir olduğundan emin olunuz."
		exit 1
	fi
	echo "Son kaç yedeği saklamak istersiniz? (Misal olarak aylık yedek alıyorsanız ve son 5 yedeği saklamayı tercih ettiyseniz son 5 aylık yedeğiniz saklanacak anlamına gelmektedir.)"
	read -r backup_count
	echo "Cron Rule : "
	read -r cron_rule
	echo -e "backup_dir \"${backup_dir}\"\nbackup_store_dir \"${backup_store_dir}\"\nbackup_count \"${backup_count}\"" > "${script_path}/data/config.dat"
	cp /etc/crontab /etc/crontab.backup.bak
	sed -i "/$(echo "/home/syntaxbender/Desktop/isletim_sistemleri/backup/backup.sh" | sed 's/[]\/$*.^[]/\\&/g')/d" /etc/crontab
	echo "${cron_rule}   root   ${script_file} -r" >> /etc/crontab
}

if [[ $istarinstalled != "tar" ]]; then
	echo "Sistemde tar paketi yüklü değil. Uygulama sonlandırılıyor."
	exit 1
fi
if [[ "$currentuser" != "root" ]]; then
    echo "Uygulamayı çalıştırmak için root yetkisine sahip olmanız gerekmektedir."
    exit 1
fi
while getopts :er flag
do
    case "${flag}" in
        e)
			edit_cron
			ischoosed=1
			break
		;;
        r)
			create_backup
			ischoosed=1
			break
		;;
    esac
done
if [[ ischoosed == 0 ]]; then
	edit_cron
fi