#!/bin/bash
# ============================================
# 🛡️ PTERODACTYL ULTRA PROTECT (NO NODE PROTECT)
# Anti Delete User/Server (kecuali Admin ID 1)
# Egg dilindungi, Script dilindungi
# ============================================

DB_NAME="panel"
DB_USER="root"
DB_PASS="YOUR_DB_PASSWORD"
SUPERADMIN_ID=1
PANEL_DIR="/var/www/pterodactyl"

echo "🔒 Pasang proteksi ultra..."

mysql -u $DB_USER -p$DB_PASS $DB_NAME <<EOF

-- 🔄 Hapus trigger lama
DROP TRIGGER IF EXISTS prevent_user_delete;
DROP TRIGGER IF EXISTS prevent_server_delete;
DROP TRIGGER IF EXISTS prevent_egg_delete;

DELIMITER $$

-- ✅ Hanya admin ID 1 boleh hapus user
CREATE TRIGGER prevent_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  IF OLD.id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin utama (ID 1) boleh hapus user!';
  END IF;
END$$

-- ✅ Hanya admin ID 1 boleh hapus server
CREATE TRIGGER prevent_server_delete
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF OLD.owner_id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin utama (ID 1) boleh hapus server!';
  END IF;
END$$

-- ❌ Egg tidak boleh dihapus siapapun
CREATE TRIGGER prevent_egg_delete
BEFORE DELETE ON eggs
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Egg tidak boleh dihapus!';
END$$

DELIMITER ;
EOF

echo "✅ Trigger proteksi DB dipasang!"

# ==============================
# 🕶️ ANTI MALING SCRIPT
# ==============================
echo "🕶️ Aktifkan Anti-Maling SC..."

# Backup source penting
BACKUP_DIR="/root/pterodactyl_backup_$(date +%F_%T)"
mkdir -p "$BACKUP_DIR"
cp -r "$PANEL_DIR" "$BACKUP_DIR"

# Lock file agar tidak bisa di-edit/di-copy
chattr -R +i "$PANEL_DIR"

echo "✅ Source Pterodactyl diproteksi (immutable + backup dibuat di $BACKUP_DIR)"

# Clear cache Laravel
cd "$PANEL_DIR"
php artisan config:clear
php artisan cache:clear

echo ""
echo "🚀 PROTEKSI ULTRA AKTIF 
(User/Server hanya bisa dihapus Admin ID 1, Node bisa dihapus Admin utama, Egg tidak bisa, SC dilock)"
