#!/bin/bash

# Update and install dependencies
apt-get update
apt-get install -y openjdk-17-jre-headless python3 python3-pip

# Mount the Minecraft data disk
mkdir -p /mnt/minecraft_data
DISK_NAME=$(lsblk -nd -o NAME,MODEL | grep minecraft-data | cut -d' ' -f1)
if [ -n "$DISK_NAME" ]; then
    mkfs.ext4 -F /dev/$DISK_NAME
    mount /dev/$DISK_NAME /mnt/minecraft_data
    echo "/dev/$DISK_NAME /mnt/minecraft_data ext4 discard,defaults 0 0" >> /etc/fstab
fi

# Install Minecraft server
mkdir -p /mnt/minecraft_data/server
cd /mnt/minecraft_data/server
wget https://launcher.mojang.com/v1/objects/c8f83c5655308435b3dcf03c06d9fe8740a77469/server.jar
echo "eula=true" > eula.txt

# Install Crafty Controller
cd /opt
git clone https://gitlab.com/crafty-controller/crafty-4.git
cd crafty-4
pip3 install -r requirements.txt
python3 crafty.py -d

# Setup systemd service for Crafty Controller
cat << EOF > /etc/systemd/system/crafty.service
[Unit]
Description=Crafty Minecraft Server Controller
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/crafty-4
ExecStart=/usr/bin/python3 /opt/crafty-4/crafty.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable crafty.service
systemctl start crafty.service

# Setup backup script
cat << EOF > /usr/local/bin/backup_minecraft.sh
#!/bin/bash
BUCKET_NAME=\$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)-minecraft-backups
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
cd /mnt/minecraft_data
tar -czf /tmp/minecraft_backup_\$TIMESTAMP.tar.gz server
gsutil cp /tmp/minecraft_backup_\$TIMESTAMP.tar.gz gs://\$BUCKET_NAME/
rm /tmp/minecraft_backup_\$TIMESTAMP.tar.gz
EOF

chmod +x /usr/local/bin/backup_minecraft.sh

# Setup daily backups
echo "0 3 * * * root /usr/local/bin/backup_minecraft.sh" > /etc/cron.d/minecraft_backup

# Setup migration script
cat << EOF > /usr/local/bin/migrate_minecraft.sh
#!/bin/bash
NEW_SERVER_IP=\$1
if [ -z "\$NEW_SERVER_IP" ]; then
    echo "Usage: \$0 <new_server_ip>"
    exit 1
fi

# Stop Minecraft server
systemctl stop crafty

# Backup current state
/usr/local/bin/backup_minecraft.sh

# Get the latest backup file
BUCKET_NAME=\$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)-minecraft-backups
LATEST_BACKUP=\$(gsutil ls gs://\$BUCKET_NAME/*.tar.gz | sort | tail -n 1)

# Copy the backup to the new server
gsutil cp \$LATEST_BACKUP gs://\$BUCKET_NAME/latest_minecraft_backup.tar.gz
gcloud compute ssh \$NEW_SERVER_IP --command="gsutil cp gs://\$BUCKET_NAME/latest_minecraft_backup.tar.gz /tmp/ && tar -xzf /tmp/latest_minecraft_backup.tar.gz -C /mnt/minecraft_data && rm /tmp/latest_minecraft_backup.tar.gz"

echo "Migration complete. Please start the Minecraft server on the new instance."
EOF

chmod +x /usr/local/bin/migrate_minecraft.sh

# Add commands to download and install mods and datapacks
# wget https://example.com/mod.jar -O /mnt/minecraft_data/server/mods/mod.jar
# wget https://example.com/datapack.zip -O /mnt/minecraft_data/server/world/datapacks/datapack.zip
