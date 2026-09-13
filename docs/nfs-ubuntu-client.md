# NFS Client Setup für Ubuntu

Anleitung zum Mounten des mireo NFS-Shares (`10.8.0.1:/data`) auf Ubuntu-Systemen.

## Voraussetzungen

- Ubuntu 20.04+ (oder Debian-basierte Distribution)
- Netzwerkverbindung zum mireo Server (10.8.0.0/24 Netz)
- Root/sudo-Rechte

## Installation

```bash
# NFS Client installieren
sudo apt update
sudo apt install -y nfs-common
```

## Manuelles Mounten (Schnelltest)

```bash
# Mount-Point erstellen
sudo mkdir -p /mnt/mireo/data

# Testen ob der Server erreichbar ist
showmount -e 10.8.0.1

# Temporär mounten
sudo mount -t nfs4 -o soft,timeo=50,retrans=2 10.8.0.1:/data /mnt/mireo/data

# Prüfen
mount | grep mireo
ls -la /mnt/mireo/data

# Schreibtest
touch /mnt/mireo/data/test-$(hostname).txt
```

## Permanentes Mounten (Auto-Mount beim Boot)

### Option 1: /etc/fstab (immer mounten)

```bash
# Mount-Point erstellen
sudo mkdir -p /mnt/mireo/data

# fstab bearbeiten
sudo nano /etc/fstab
```

Folgende Zeile hinzufügen:

```
10.8.0.1:/data  /mnt/mireo/data  nfs4  soft,timeo=50,retrans=2,_netdev  0  0
```

**Parameter:**
- `soft` - Timeout statt endloses Hängen wenn Server nicht erreichbar
- `timeo=50` - 5 Sekunden Timeout (50 x 0.1s)
- `retrans=2` - 2 Wiederholungsversuche
- `_netdev` - Warten bis Netzwerk verfügbar ist

```bash
# Testen ohne Reboot
sudo mount -a

# Status prüfen
df -h | grep mireo
```

### Option 2: systemd.automount (on-demand)

Mountet nur wenn darauf zugegriffen wird - vermeidet Bootprobleme wenn Server offline ist.

```bash
# systemd mount unit erstellen
sudo nano /etc/systemd/system/mnt-mireo-data.mount
```

Inhalt:

```ini
[Unit]
Description=mireo NFS data share
Requires=network-online.target
After=network-online.target

[Mount]
What=10.8.0.1:/data
Where=/mnt/mireo/data
Type=nfs4
Options=soft,timeo=50,retrans=2

[Install]
WantedBy=multi-user.target
```

Automount unit erstellen:

```bash
sudo nano /etc/systemd/system/mnt-mireo-data.automount
```

Inhalt:

```ini
[Unit]
Description=Automount mireo NFS data share

[Automount]
Where=/mnt/mireo/data
TimeoutIdleSec=300

[Install]
WantedBy=multi-user.target
```

Aktivieren:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mnt-mireo-data.automount
sudo systemctl start mnt-mireo-data.automount

# Status prüfen
systemctl status mnt-mireo-data.automount

# Automount triggern
ls /mnt/mireo/data
```

## User-Symlink erstellen

```bash
# Symlink für einfachen Zugriff
ln -s /mnt/mireo/data ~/data

# Verwenden
cd ~/data
echo "Hello from $(hostname)" > test.txt
ls -la ~/data
```

## Berechtigungen

Der mireo NFS-Server verwendet:
- **all_squash** - Alle Zugriffe werden gemappt auf:
  - UID 1000 (typisch erster User)
  - GID 100 (users-Gruppe)

Falls dein Ubuntu-User eine andere UID hat, prüfe mit:

```bash
id
# uid=1000(username) gid=1000(username) ...
```

Bei abweichender UID kannst du entweder:
1. **Empfohlen:** Via GUI/Dolphin/Nautilus zugreifen (funktioniert meist transparent)
2. Über FUSE-Wrapper mit User-Mapping (komplizierter)

## Troubleshooting

### Mount schlägt fehl: "Connection timed out"

```bash
# Server-Erreichbarkeit prüfen
ping -c 3 10.8.0.1

# NFS-Port prüfen
nc -zv 10.8.0.1 2049

# Firewall prüfen (falls aktiviert)
sudo ufw status
# NFS erlauben falls nötig:
sudo ufw allow from 10.8.0.0/24 to any port 2049
```

### Mount hängt beim Boot

- Option 1 (fstab): Füge `nofail` Option hinzu:
  ```
  10.8.0.1:/data  /mnt/mireo/data  nfs4  soft,timeo=50,retrans=2,_netdev,nofail  0  0
  ```

- Option 2: Verwende systemd.automount (siehe oben)

### Schreibrechte fehlen

```bash
# Aktuelle User-ID prüfen
id -u  # sollte 1000 sein

# Falls anders, beim Mounten anpassen (nicht empfohlen):
sudo mount -t nfs4 -o soft,timeo=50,retrans=2,uid=1000,gid=1000 10.8.0.1:/data /mnt/mireo/data
```

### Mount-Punkt ist schon gemountet

```bash
# Unmounten
sudo umount /mnt/mireo/data

# Falls "device is busy":
sudo umount -l /mnt/mireo/data  # lazy unmount
# oder
sudo fuser -km /mnt/mireo/data  # Prozesse killen die zugreifen
```

## Performance-Tuning

Für bessere Performance bei großen Dateien:

```bash
# In fstab oder mount-Options:
rsize=1048576,wsize=1048576,hard,intr,tcp
```

**Achtung:** `hard` mount kann Prozesse blockieren wenn Server ausfällt. Nur verwenden wenn Server sehr stabil ist.

## Weitere Infos

- **mireo Server-IP:** 10.8.0.1
- **Export:** `/data` für Netz `10.8.0.0/24`
- **Avahi:** Server annonciert sich via mDNS als `mireo.local` (falls avahi-daemon auf Ubuntu läuft)
- **Netdata Monitoring:** http://10.8.0.1:19999

## Desktop-Integration

### GNOME (Ubuntu Desktop)

Nautilus unterstützt NFS nativ:

1. Files öffnen
2. "Other Locations" → "Connect to Server"
3. Eingeben: `nfs://10.8.0.1/data`
4. Enter → Bookmark setzen

### KDE Plasma

Dolphin via Avahi:

1. Dolphin öffnen
2. Sidebar: "Network" → "Shared Folders (NFS)"
3. mireo sollte automatisch erscheinen
4. Oder manuell: `nfs://10.8.0.1/data` in Adresszeile

## Zusammenfassung Befehle

```bash
# Einmalig Setup
sudo apt install -y nfs-common
sudo mkdir -p /mnt/mireo/data
echo "10.8.0.1:/data  /mnt/mireo/data  nfs4  soft,timeo=50,retrans=2,_netdev,nofail  0  0" | sudo tee -a /etc/fstab
sudo mount -a
ln -s /mnt/mireo/data ~/data

# Testen
echo "test" > ~/data/test-ubuntu.txt
ls -la ~/data
```
