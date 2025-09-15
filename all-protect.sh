mysql -u $DB_USER -p$DB_PASS $DB_NAME <<EOF

-- Hapus trigger lama
DROP TRIGGER IF EXISTS prevent_user_delete;
DROP TRIGGER IF EXISTS prevent_server_delete;
DROP TRIGGER IF EXISTS prevent_node_delete;
DROP TRIGGER IF EXISTS prevent_egg_delete;

DELIMITER $$

-- User hanya bisa dihapus oleh Admin ID 1 (cek kolom panel user_id bukan root DB)
CREATE TRIGGER prevent_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  -- Hanya izinkan delete jika ID user = 1 (superadmin)
  IF OLD.id = 1 THEN
    -- biarkan
  ELSE
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya superadmin (ID 1) boleh hapus user!';
  END IF;
END$$

-- Server hanya boleh dihapus jika owner_id = 1
CREATE TRIGGER prevent_server_delete
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF OLD.owner_id = 1 THEN
    -- biarkan
  ELSE
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya superadmin (ID 1) boleh hapus server!';
  END IF;
END$$

-- Node tidak boleh dihapus sama sekali
CREATE TRIGGER prevent_node_delete
BEFORE DELETE ON nodes
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Node tidak boleh dihapus!';
END$$

-- Egg tidak boleh dihapus sama sekali
CREATE TRIGGER prevent_egg_delete
BEFORE DELETE ON eggs
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Egg tidak boleh dihapus!';
END$$

DELIMITER ;
EOF
