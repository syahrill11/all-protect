#!/bin/bash

# ============================================
# 🛡️ PTERODACTYL PROTECT ALL (FIXED)
# Anti-Delete & Anti-Intip (tetap bisa create user/server)
# ============================================

DB_USER="root"
PANEL_DIR="/var/www/pterodactyl"
ENV_FILE="$PANEL_DIR/.env"
TARGET_FILE="$PANEL_DIR/app/Repositories/Eloquent/ServerRepository.php"
BACKUP_FILE="$TARGET_FILE.bak"
SUPERADMIN_ID=1

# 🔍 Ambil nama database dari .env
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Tidak menemukan .env"
  exit 1
fi

DB=$(grep DB_DATABASE "$ENV_FILE" | cut -d '=' -f2)

if [[ -z "$DB" ]]; then
  echo "❌ Tidak dapat membaca DB dari .env"
  exit 1
fi

echo "📦 Database aktif: $DB"

# ===============================
# 💣 Proteksi DELETE / UPDATE DB
# ===============================
echo "🔒 Memasang trigger proteksi..."

mysql -u $DB_USER <<EOF
USE $DB;

-- Hapus trigger lama kalau ada
DROP TRIGGER IF EXISTS prevent_user_delete;
DROP TRIGGER IF EXISTS prevent_server_delete;
DROP TRIGGER IF EXISTS prevent_node_delete;
DROP TRIGGER IF EXISTS prevent_egg_delete;
DROP TRIGGER IF EXISTS prevent_setting_edit;

DELIMITER $$

-- ❌ Blokir HAPUS user kecuali admin ID 1
CREATE TRIGGER prevent_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  IF OLD.id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin ID 1 boleh hapus user';
  END IF;
END$$

-- ❌ Blokir HAPUS server kecuali milik admin ID 1
CREATE TRIGGER prevent_server_delete
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF OLD.owner_id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin ID 1 boleh hapus server';
  END IF;
END$$

-- ❌ Node tidak boleh dihapus siapapun
CREATE TRIGGER prevent_node_delete
BEFORE DELETE ON nodes
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Node tidak boleh dihapus!';
END$$

-- ❌ Egg tidak boleh dihapus siapapun
CREATE TRIGGER prevent_egg_delete
BEFORE DELETE ON eggs
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Egg tidak boleh dihapus!';
END$$

-- ❌ Setting tidak boleh diubah siapapun
CREATE TRIGGER prevent_setting_edit
BEFORE UPDATE ON settings
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Setting tidak boleh diubah!';
END$$

DELIMITER ;
EOF

echo "✅ Trigger MySQL dipasang."

# ===============================
# 🕶️ Proteksi ANTI-INTIP (Laravel)
# ===============================

echo "🕶️ Memasang Anti-Intip Panel (hanya ID 1 bisa lihat semua)..."

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "❌ File tidak ditemukan: $TARGET_FILE"
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
  echo "📦 Backup dibuat: $BACKUP_FILE"
fi

# Rewrite fungsi getUserServers agar hanya ID 1 yg bisa lihat semua
awk -v id="$SUPERADMIN_ID" '
/public function getUserServers/ {
  print "    public function getUserServers(User $user) {"
  print "        // 🕶️ Anti-intip untuk admin utama (ID 1)"
  print "        if ($user->id !== " id ") {"
  print "            return $this->model->where(\"owner_id\", $user->id)->get();"
  print "        }"
  print "        return $this->model->get();"
  print "    }"
  skip=1
  next
}
skip && /^}/ { skip=0; next }
!skip { print }
' "$BACKUP_FILE" > "$TARGET_FILE"

echo "✅ Anti-intip Laravel ditulis ulang."

# Refresh Laravel cache
cd "$PANEL_DIR"
php artisan config:clear
php artisan cache:clear

echo ""
echo "✅ PROTEKSI AKTIF (Tetap bisa CREATE User/Server, tapi DELETE dibatasi)"
