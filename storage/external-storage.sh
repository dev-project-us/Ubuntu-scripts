#!/bin/bash

# This script sets up a media server folder structure, configures fstab mounts,
# sets up Samba shares, and installs Docker on Debian 12.

# === Variables ===
smbcredentials="/etc/samba/.smbcredentials"

# === Create folder structure ===
echo "Creating /data folder structure..."
sudo mkdir -p /data
sudo mkdir -p /data/cloud
sudo mkdir -p /data/media/music
sudo mkdir -p /data/media/movies/Movies1
sudo mkdir -p /data/media/movies/Movies2
sudo mkdir -p /data/media/movies/Movies3
sudo mkdir -p /data/media/tv/TvShows1
sudo mkdir -p /data/media/tv/TvShows2
sudo mkdir -p /data/media/tv/TvShows3
sudo mkdir -p /data/media/tv/TvShows4
sudo mkdir -p /data/torrents/{movies,tv,music,books}
sudo mkdir -p /data/usenet/{complete,incomplete}

echo "✅ Folder structure created."

# === Install NTFS support ===
echo "Installing NTFS-3G support..."
sudo apt update
sudo apt install -y ntfs-3g

# === Clean and update /etc/fstab ===
echo "Cleaning up /etc/fstab..."
sudo sed -i '/^# UNCONFIGURED FSTAB FOR BASE SYSTEM/d' /etc/fstab

echo "Appending mount entries to /etc/fstab..."
sudo tee -a /etc/fstab > /dev/null <<EOF

# Movies
UUID=A4969CA8969C7C8C    /data/media/movies/Movies1    ntfs    defaults    0    0
UUID=f03421c7-d075-47fa-b621-b1758eef8073    /data/media/movies/Movies2    ext4    defaults    0    0
UUID=cc823605-6b46-4c84-bbbc-22f716344d38    /data/media/movies/Movies3    ext4    defaults    0    0

# TV Shows
UUID=80657b84-81ed-47f2-9bb7-4a607a3f2fee    /data/media/tv/TvShows1    ext4    defaults    0    0
UUID=c590249a-9c96-4e83-86ff-9b3ee1345427    /data/media/tv/TvShows2    ext4    defaults    0    0
UUID=cd22f998-0f68-4df9-87b0-fba8bd59bfc9    /data/media/tv/TvShows3    ext4    defaults    0    0
UUID=2949390f-680f-4c29-8c68-9f75ea51932d    /data/media/tv/TvShows4    ext4    defaults    0    0

# Docker
UUID=a577d2ff-708d-4df3-abcd-31c8a502edad    /docker	    ext4    defaults    0    0

# Cloud
UUID=5b76065e-d48e-473b-9c63-9d1230d37cf1    /data/cloud    ext4    defaults    0    0

EOF

# === Reload and mount drives ===
sudo systemctl daemon-reexec
sudo mount -a

# === Verify mount points ===
echo "Verifying mounted drives..."
for mount in /data/media/movies/Movies{1..3} /data/media/tv/TvShows{1..4} /docker; do
    if mount | grep -q "$mount"; then
        echo "✅ Mounted: $mount"
    else
        echo "❌ Not mounted: $mount"
    fi
done

# === Create hidden Samba credentials file ===
if [ ! -f "$smbcredentials" ]; then
    echo "Creating hidden Samba credentials file at $smbcredentials"
    read -p "Enter Samba username: " username
    read -p "Enter Samba password: " password  # This will show on screen
    echo
    echo "username=$username" | sudo tee "$smbcredentials" > /dev/null
    echo "password=$password" | sudo tee -a "$smbcredentials" > /dev/null
    sudo chmod 600 "$smbcredentials"
else
    echo "Samba credentials file already exists: $smbcredentials"
fi

# === Install Samba and CIFS utilities ===
echo "Installing Samba and cifs-utils..."
sudo apt install -y samba cifs-utils
sudo systemctl enable smbd
sudo systemctl start smbd

# === Configure Samba shares ===
smbconf="/etc/samba/smb.conf"
sudo cp "$smbconf" "$smbconf.bak"

sudo tee -a "$smbconf" > /dev/null <<'EOF'

[Movies1]
   comment = Movies1
   path = /data/media/movies/Movies1
   read only = no
   browsable = yes
   writable = yes

[Movies2]
   comment = Movies2
   path = /data/media/movies/Movies2
   read only = no
   browsable = yes
   writable = yes

[Movies3]
   comment = Movies3
   path = /data/media/movies/Movies3
   read only = no
   browsable = yes
   writable = yes

[TvShows1]
   comment = TvShows1
   path = /data/media/tv/TvShows1
   read only = no
   browsable = yes
   writable = yes

[TvShows2]
   comment = TvShows2
   path = /data/media/tv/TvShows2
   read only = no
   browsable = yes
   writable = yes

[TvShows3]
   comment = TvShows3
   path = /data/media/tv/TvShows3
   read only = no
   browsable = yes
   writable = yes

[TvShows4]
   comment = TvShows4
   path = /data/media/tv/TvShows4
   read only = no
   browsable = yes
   writable = yes

EOF

sudo systemctl restart smbd

# === Install Docker (Debian) ===
echo "Installing Docker and Docker Compose..."

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt install docker-compose -y

# === Add current user to docker group ===
sudo usermod -aG docker "$USER"

echo "✅ Setup complete!"

# === Optional reboot ===
read -p "Reboot now to finalize setup? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo reboot now
fi
