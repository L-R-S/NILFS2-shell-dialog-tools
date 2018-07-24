#!/bin/bash

# NILFS2 bash dialog tools
# (c) 2018 Lucjan R. Szreter
# GNU General Public License v 3.0

#Selecting device
#When leaved empty system will try to find nilfs2 device automaticaly 
#good if you have only one NILFS2 filesystem 
device=`dialog --stdout --title "Choose device" --inputbox "Leave empty for default" 0 0`

#	if you have more nilfs2 devices you can choose one by editing and uncomenting next line
#device="/dev/sda1"
#	or make youself some menu…

answer_file=/tmp/nilfs-admin-answers
mount_point=/mnt/

menu_show () {

    menu=`dialog --stdout --title "NILFS2 tools" --menu "Select action:" 0 0 0 \
    1 "List SNAPSHOTS only" \
    2 "List checkpoints" \
    3 "Make a SNAPSHOT (opt. mount)" \
    4 "Make a checkpoint" \
    5 "Mount SNAPSHOT" \
    6 "Umount SNAPSHOT (opt. convert back to checkpoint)" \
    7 "Convert chekpoint to SNAPSHOT (opt. mount)" \
    8 "Convert SNAPSHOT to checkpoint" \
    9 "Remove checkpoint(s)"` 
#    10 "Advanced tools" – here will be sub menu with access to other NILFS2 tools 

}

snapshot_list () {
    local lines=`dialog --stdout --title "SNAPSHOT list" --inputbox "Show last lines:" 0 0 10`
    lscp -r -s -n $lines $device 1>$answer_file
    dialog --scrollbar --title "SNAPSHOT list" --textbox $answer_file 0 0 
    rm $answer_file
}

checkpoint_list () {
    local lines=`dialog --stdout --title "Checkpoints list" --inputbox "Show last lines:" 0 0 20`
    lscp -r -n $lines $device 1>$answer_file
    dialog --scrollbar --title "Checkpoints list" --textbox $answer_file 0 0 
}

snapshot_make () {
    local id=`mkcp -s -p $device`
    dialog --stdout --title "New SNSPASHOT id: $id" --yesno "Mount this new SNAPSHOT?" 0 0
    local mount=$?

    if (( $mount == 0 )) ;
	then
	    mkdir -p "$mount_point$id"
	    mount -t nilfs2 -r -o cp=$id $device "$mount_point$id"
    fi
}

checkpoint_make () {
    local id=`mkcp -p $device`
    dialog --scrollbar --title "New checkpoint id" --msgbox $id 0 0 
}

checkpoint_remove () {

    local type=`dialog --stdout --title "Remove checkopint(s)" --menu "" 0 0 0 \
	1 "Single checkpoint" \
	2 "From id to id" \
	3 "Equal and smaller than id" \
	4 "Equal or greater than id"`

    case $type in
	1) 
	    local id=`dialog --stdout --title "Checkpoint to remove" --inputbox "Id:" 0 0`
	    rmcp -f $id
	    ;;
	2) 
	    local range=`dialog --stdout --form "Remove checkpoints" 5 0 3 \
		"From:" 0 0 "" 0 10 20 0 \
		"To:" 2 1 "" 2 10 20 0`
	    readarray -t range <<< "$range"
	    rmcp -f "${range[0]}..${range[1]}"
	    ;;
	3)
	    local id=`dialog --stdout --title "Remove checkpoints with id smaller or equal than" --inputbox "Id:" 0 0`
	    rmcp -f "..$id"
	    ;;
	4) 
	    local id=`dialog --stdout --title "Remove checkpoints with id equal or greater than" --inputbox "Id:" 0 0`
	    rmcp -f "$id.."
	    ;;
    esac
}

snapshot_mount () {
    local id=`dialog --stdout --inputbox "Snapshot to mount:" 0 0`
    mkdir -p "$mount_point$id"
    mount -t nilfs2 -r -o cp=$id $device "$mount_point$id"
}

snapshot_umount () {
    dialog --msgbox "Folder selected in next step will be unmounted and removed! Use with caution!" 0 0
    local snapshot_path=`dialog --stdout --dselect $mount_point 0 0`

    if (( $snapshot_path == "" )) ;
	then return
    fi

    dialog --stdout --title "Please confirm" --yesno "Folder $snapshot_path will be unmounted and deleted" 0 0
    local ok=$?

    if (( $ok <> 0 )) ;
	then return
    fi

    local id=${snapshot_path##*/}
    umount -l $snapshot_path
    rm -rf $snapshot_path

    dialog --stdout --yesno "Convert SNAPSHOT $id back to checkpoint?" 0 0
    local convertback=$?

    if (( $convertback == 0 )) ;
    then
        chcp cp $device $id
    fi
}

cc2ss () {
    local id=`dialog --stdout --inputbox "Convert checkpoint to SNAPSHOT:" 0 0`
    chcp ss $device $id

    dialog --stdout --yesno "Mount SNAPSHOT $id in $mount_point$id?" 0 0
    local mount=$?

    if (( $mount == 0 )) ;
	then
	    mkdir -p "$mount_point$id"
	    mount -t nilfs2 -r -o cp=$id $device "$mount_point$id"
    fi
}

ss2cc () {
    local id=`dialog --stdout --inputbox "Convert SNAPSHOT to checkpoint:" 0 0`
    chcp cp $device $id
}


# main loop

while :
do
    menu_show

    if [ -z "$menu" ] ; 
	then 
	    exit
    fi

    case $menu in
    1) snapshot_list ;;
    2) checkpoint_list ;;
    3) snapshot_make ;;
    4) checkpoint_make ;;
    5) snapshot_mount ;;
    6) snapshot_umount ;;
    7) cc2ss ;;
    8) ss2cc ;;
    9) checkpoint_remove ;;
    esac

    rm $answer_file

done

