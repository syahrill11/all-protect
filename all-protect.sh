#!/bin/bash
# ============================================
# 🛡️ PTERODACTYL ULTRA PROTECT (Superadmin Safe)
# - User & Server hanya bisa dihapus oleh Admin ID 1
# - Node & Egg tidak bisa dihapus sama sekali
# ============================================

DB_NAME="panel"
DB_USER="root"
DB_PASS="YOUR_DB_PASSWORD"   # << ganti dengan password MySQL root
SUPERADMIN_ID=1

echo "🔒 Pasang proteksi ultra Pterodactyl..."

mysql -u $DB_USER -p$DB_PASS $DB_NAME <<EOF

-- Hapus trigger lama jika ada
DROP TRIGGER IF EXISTS prevent_user_delete;
DROP TRIGGER IF EXISTS prevent_user_softdelete;
DROP TRIGGER IF EXISTS prevent_server_delete;
DROP TRIGGER IF EXISTS prevent_server_softdelete;
DROP TRIGGER IF EXISTS prevent_node_delete;
DROP TRIGGER IF EXISTS prevent_node_softdelete;
DROP TRIGGER IF EXISTS prevent_egg_delete;
DROP TRIGGER IF EXISTS prevent_egg_softdelete;

DELIMITER $$

-- ==========================
-- USERS
-- ==========================

CREATE TRIGGER prevent_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  IF OLD.id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ User hanya boleh dihapus oleh Superadmin (ID 1)!';
  END IF;
END$$

CREATE TRIGGER prevent_user_softdelete
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL AND OLD.id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ User tidak boleh dihapus (soft delete dicegah)!';
  END IF;
END$$

-- ==========================
-- SERVERS
-- ==========================

CREATE TRIGGER prevent_server_delete
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF OLD.owner_id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Server hanya boleh dihapus Superadmin!';
  END IF;
END$$

CREATE TRIGGER prevent_server_softdelete
BEFORE UPDATE ON servers
FOR EACH ROW
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL AND OLD.owner_id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Server tidak boleh dihapus (soft delete dicegah)!';
  END IF;
END$$

-- ==========================
-- NODES
-- ==========================

CREATE TRIGGER prevent_node_delete
BEFORE DELETE ON nodes
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Node tidak boleh dihapus!';
END$$

CREATE TRIGGER prevent_node_softdelete
BEFORE UPDATE ON nodes
FOR EACH ROW
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Node tidak boleh dihapus (soft delete dicegah)!';
  END IF;
END$$

-- ==========================
-- EGGS
-- ==========================

CREATE TRIGGER prevent_egg_delete
BEFORE DELETE ON eggs
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Egg tidak boleh dihapus!';
END$$

CREATE TRIGGER prevent_egg_softdelete
BEFORE UPDATE ON eggs
FOR EACH ROW
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Egg tidak boleh dihapus (soft delete dicegah)!';
  END IF;
END$$

DELIMITER ;
EOF

echo "✅ Proteksi database aktif!"
echo "👉 User & Server hanya bisa dihapus oleh Superadmin (ID=$SUPERADMIN_ID)"
echo "👉 Node & Egg tidak bisa dihapus sama sekali"
