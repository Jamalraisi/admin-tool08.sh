#!/bin/bash

# Run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root"
  exit
fi

LOG_FILE="/var/log/admin-tool.log"
touch "$LOG_FILE"

while true; do
  echo ""
  echo "========= Admin Tool Menu ========="
  echo "1. Create new users"
  echo "2. Create new groups"
  echo "3. Create new directories"
  echo "4. Add user to a group"
  echo "5. Get user/group/directory info"
  echo "6. List by type (Users/Groups/Dirs)"
  echo "7. Delete user/group/directory"
  echo "8. Lock/Unlock a user account"
  echo "9. Change a user's password"
  echo "10. List all users with details"
  echo "11. Change ownership of a directory"
  echo "12. Change permissions of a file or directory"
  echo "13. Backup user home directory"
  echo "14. Check disk usage"
  echo "15. Show last login info"
  echo "16. Display system info"
  echo "17. Run custom script"
  echo "18. List user backups"
  echo "19. List file/directory with permissions"
  echo "20. Create multiple files and directories"
  echo "21. Exit"
  echo "==================================="
  read -p "Enter your choice [1-21]: " choice

  echo "[$(date)] Selected option $choice" >> "$LOG_FILE"

  case $choice in
    1)
      read -p "Enter comma-separated usernames to create (e.g. user1,user2,user3): " usernames
      IFS=',' read -r -a userArray <<< "$usernames"
      for username in "${userArray[@]}"; do
        username=$(echo "$username" | xargs)
        if id "$username" &>/dev/null; then
          echo "⚠️ User '$username' already exists. Skipping."
        else
          useradd -m "$username" && echo "✅ User '$username' created." && echo "User '$username' created" >> "$LOG_FILE"
        fi
      done
      ;;
    2)
      read -p "Enter comma-separated group names to create (e.g. group1,group2,group3): " groups
      IFS=',' read -r -a groupArray <<< "$groups"
      for groupname in "${groupArray[@]}"; do
        groupname=$(echo "$groupname" | xargs)
        if getent group "$groupname" > /dev/null; then
          echo "⚠️ Group '$groupname' already exists. Skipping."
        else
          groupadd "$groupname" && echo "✅ Group '$groupname' created." && echo "Group '$groupname' created" >> "$LOG_FILE"
        fi
      done
      ;;
    3)
      read -p "Enter comma-separated directory paths to create (e.g. /home/user1/dir1,/home/user2/dir2): " dirs
      IFS=',' read -r -a dirArray <<< "$dirs"
      for dirpath in "${dirArray[@]}"; do
        dirpath=$(echo "$dirpath" | xargs)
        if [ -d "$dirpath" ]; then
          echo "⚠️ Directory '$dirpath' already exists. Skipping."
        else
          mkdir -p "$dirpath" && echo "✅ Directory '$dirpath' created." && echo "Directory '$dirpath' created" >> "$LOG_FILE"
        fi
      done
      ;;
    4)
      read -p "Enter comma-separated usernames (e.g. user1,user2) to add to a group: " usernames
      read -p "Enter the group name to add users to: " groupname
      IFS=',' read -r -a userArray <<< "$usernames"
      for username in "${userArray[@]}"; do
        username=$(echo "$username" | xargs)
        if id "$username" &>/dev/null; then
          usermod -aG "$groupname" "$username" && echo "✅ Added '$username' to '$groupname'." && echo "User '$username' added to group '$groupname'" >> "$LOG_FILE"
        else
          echo "❌ User '$username' does not exist."
        fi
      done
      ;;
    5)
      echo "========== User/Group/Directory Info =========="
      read -p "Enter the username to get information: " username
      id "$username" && echo "User '$username' information displayed."
      groups "$username" && echo "Groups of '$username' displayed."
      echo "Directories owned by $username:"
      find / -type d -user "$username" 2>/dev/null
      echo "Files owned by $username:"
      find / -type f -user "$username" 2>/dev/null
      ;;
    6)
      read -p "Enter type (U=Users, G=Groups, D=Directories): " type
      case $type in
        U|u)
          echo "📄 Users created by admin:"
          cut -d: -f1 /etc/passwd | while read user; do
            if [ -d "/home/$user" ]; then
              echo "$user"
            fi
          done
          ;;
        G|g)
          echo "📄 Groups created by admin:"
          cut -d: -f1 /etc/group | while read group; do
            if [[ $(getent group "$group" | cut -d: -f3) -ge 1000 ]]; then
              echo "$group"
            fi
          done
          ;;
        D|d)
          echo "📄 Directories created by admin under /home:"
          find /home -maxdepth 1 -type d -exec stat --format='%U %n' {} \; | grep -E '^(jamal|root)'
          ;;
        *)
          echo "❌ Invalid type. Use U for Users, G for Groups, D for Directories."
          ;;
      esac
      ;;
    7)
      read -p "Delete (U=User, G=Group, D=Directory): " dtype
      case $dtype in
        U|u)
          read -p "Enter the usernames to delete (comma-separated): " delusers
          IFS=',' read -r -a delUserArray <<< "$delusers"
          for deluser in "${delUserArray[@]}"; do
            deluser=$(echo "$deluser" | xargs)
            if id "$deluser" &>/dev/null; then
              userdel -r "$deluser" && echo "✅ User '$deluser' deleted." && echo "User '$deluser' deleted" >> "$LOG_FILE"
            else
              echo "❌ User '$deluser' does not exist."
            fi
          done
          ;;
        G|g)
          read -p "Enter the group names to delete (comma-separated): " delgroups
          IFS=',' read -r -a delGroupArray <<< "$delgroups"
          for delgroup in "${delGroupArray[@]}"; do
            delgroup=$(echo "$delgroup" | xargs)
            if getent group "$delgroup" > /dev/null; then
              groupdel "$delgroup" && echo "✅ Group '$delgroup' deleted." && echo "Group '$delgroup' deleted" >> "$LOG_FILE"
            else
              echo "❌ Group '$delgroup' does not exist."
            fi
          done
          ;;
        D|d)
          read -p "Enter the directories to delete (comma-separated): " deldirs
          IFS=',' read -r -a delDirArray <<< "$deldirs"
          for deldir in "${delDirArray[@]}"; do
            deldir=$(echo "$deldir" | xargs)
            if [ -d "$deldir" ]; then
              rm -r "$deldir" && echo "✅ Directory '$deldir' deleted." && echo "Directory '$deldir' deleted" >> "$LOG_FILE"
            else
              echo "❌ Directory '$deldir' does not exist."
            fi
          done
          ;;
        *)
          echo "❌ Invalid delete type. Use U, G, or D."
          ;;
      esac
      ;;
    8)
      read -p "Enter usernames (comma-separated) to lock/unlock: " uname
      read -p "Action (L=Lock, U=Unlock): " act
      IFS=',' read -r -a userArray <<< "$uname"
      for username in "${userArray[@]}"; do
        username=$(echo "$username" | xargs)
        if id "$username" &>/dev/null; then
          case $act in
            L|l)
              passwd -l "$username" && echo "🔒 User '$username' locked." && echo "User '$username' locked" >> "$LOG_FILE"
              ;;
            U|u)
              passwd -u "$username" && echo "🔓 User '$username' unlocked." && echo "User '$username' unlocked" >> "$LOG_FILE"
              ;;
            *)
              echo "❌ Invalid action. Use L or U."
              ;;
          esac
        else
          echo "❌ User '$username' does not exist."
        fi
      done
      ;;
    9)
      read -p "Enter username to change password: " uname
      if id "$uname" &>/dev/null; then
        passwd "$uname"
        echo "🔐 Password for '$uname' changed." >> "$LOG_FILE"
      else
        echo "❌ User '$uname' does not exist."
      fi
      ;;
    10)
      echo "👥 All users with details:"
      awk -F: '{ print $1, $3, $4, $7, $6 }' /etc/passwd | column -t
      ;;
    11)
      read -p "Enter directory path: " path
      read -p "Enter new owner: " owner
      read -p "Enter new group: " group
      chown "$owner":"$group" "$path" && echo "✅ Ownership changed." && echo "Ownership of '$path' changed to $owner:$group" >> "$LOG_FILE"
      ;;
    12)
      read -p "Enter file/directory path: " path
      read -p "Enter permissions (e.g., 755): " perms
      chmod "$perms" "$path" && echo "✅ Permissions set." && echo "Permissions of '$path' set to $perms" >> "$LOG_FILE"
      ;;
    13)
      read -p "Enter username to backup: " uname
      homedir="/home/$uname"
      if [ -d "$homedir" ]; then
        tar czf "/tmp/${uname}_backup.tar.gz" "$homedir" && echo "✅ Backup created at /tmp/${uname}_backup.tar.gz" && echo "Backup of '$uname' created" >> "$LOG_FILE"
      else
        echo "❌ No home directory for user '$uname'."
      fi
      ;;
    14)
      echo "💽 Disk usage:"
      df -h
      du -sh /home/* 2>/dev/null
      ;;
    15)
      echo "📅 Last login info:"
      lastlog
      ;;
    16)
      echo "🖥️ System Info:"
      uname -a
      uptime
      free -h
      ;;
    17)
      read -p "Enter script path to run: " script
      if [ -x "$script" ]; then
        "$script"
        echo "🛠️ Custom script '$script' executed." >> "$LOG_FILE"
      else
        echo "❌ Invalid or non-executable script."
      fi
      ;;
    18)
      echo "📦 Listing backups in $BACKUP_DIR:"
      ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "❌ No backups found."
      ;;
    19)
      read -p "Enter the path to list (e.g., /home): " path
      if [ -d "$path" ]; then
        echo "🔍 Listing contents of '$path' with permissions:"
        find "$path" -exec ls -ld {} \;
      else
        echo "❌ Directory does not exist."
      fi
      ;;
    20)
      read -p "Enter comma-separated file paths to create (e.g. /home/ali/f1.txt,/home/ali/f2.txt): " files
      read -p "Enter comma-separated directory paths to create (e.g. /home/ali/d1,/home/ali/d2): " dirs

      IFS=',' read -r -a fileArray <<< "$files"
      for filepath in "${fileArray[@]}"; do
        filepath=$(echo "$filepath" | xargs)
        if [ -f "$filepath" ]; then
          echo "⚠️ File '$filepath' already exists. Skipping."
        else
          touch "$filepath" && echo "✅ File '$filepath' created." && echo "File '$filepath' created" >> "$LOG_FILE"
        fi
      done

      IFS=',' read -r -a dirArray <<< "$dirs"
      for dirpath in "${dirArray[@]}"; do
        dirpath=$(echo "$dirpath" | xargs)
        if [ -d "$dirpath" ]; then
          echo "⚠️ Directory '$dirpath' already exists. Skipping."
        else
          mkdir -p "$dirpath" && echo "✅ Directory '$dirpath' created." && echo "Directory '$dirpath' created" >> "$LOG_FILE"
        fi
      done
      ;;
    21)
      echo "👋 Exiting."
      break
      ;;
    *)
      echo "❌ Invalid choice. Try again."
      ;;
  esac

  echo "" >> "$LOG_FILE"
done
