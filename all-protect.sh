#!/bin/bash
# =========================================
# 🛡️ Anti Delete Server + User (Fixed)
# Proteksi:
#   - User ID=1 tidak bisa dihapus
#   - Server milik ID=1 tidak bisa dihapus
# User/server lain masih bisa dihapus oleh ID=1
# =========================================

ENV="/var/www/pterodactyl/.env"
OWNER_ID=1

# Ambil DB info dari .env
DB_USER=$(grep DB_USERNAME $ENV | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD $ENV | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE $ENV | cut -d '=' -f2)
DB_HOST=$(grep DB_HOST $ENV | cut -d '=' -f2)

DB_HOST=${DB_HOST:-127.0.0.1}

# Pasang trigger proteksi
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<SQL

-- Proteksi hapus user: cegah hapus superadmin
DROP TRIGGER IF EXISTS prevent_delete_user;
DELIMITER $$
CREATE TRIGGER prevent_delete_user
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  -- Blokir hanya kalau target user yang dihapus = owner_id
  IF OLD.id = $OWNER_ID THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '❌ User ID=1 (Superadmin) tidak boleh dihapus!';
  END IF;
END$$
DELIMITER ;

-- Proteksi hapus server: cegah hapus server milik superadmin
DROP TRIGGER IF EXISTS prevent_delete_server;
DELIMITER $$
CREATE TRIGGER prevent_delete_server
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  -- Blokir hanya kalau server yang mau dihapus milik owner_id
  IF OLD.owner_id = $OWNER_ID THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '❌ Server milik Superadmin (id=1) tidak boleh dihapus!';
  END IF;
END$$
DELIMITER ;

SQL

echo "✅ Proteksi berhasil dipasang!
- User ID=$OWNER_ID tidak bisa dihapus
- Server milik ID=$OWNER_ID tidak bisa dihapus
- Admin ID=$OWNER_ID tetap bisa hapus user/server lain"
