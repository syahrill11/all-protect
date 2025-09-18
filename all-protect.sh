#!/bin/bash
# =========================================
# 🛡️ Proteksi Pterodactyl Anti-Delete/Edit
# Aturan:
#   - Semua orang TIDAK bisa hapus/edit server atau user milik ID 1.
#   - Semua orang TIDAK bisa edit node.
#   - Hanya ID 1 yang bisa hapus/edit server dan user lainnya.
# =========================================

ENV="/var/www/pterodactyl/.env"
OWNER_ID=1

# Ambil info DB dari .env
DB_USER=$(grep DB_USERNAME $ENV | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD $ENV | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE $ENV | cut -d '=' -f2)
DB_HOST=$(grep DB_HOST $ENV | cut -d '=' -f2)

DB_HOST=${DB_HOST:-127.0.0.1}

echo "Memasang trigger proteksi pada database '$DB_NAME'..."

mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<SQL

-- Proteksi hapus server
SET @OWNER_ID = 1;

DROP TRIGGER IF EXISTS prevent_delete_server;
DELIMITER $$
CREATE TRIGGER prevent_delete_server
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
    DECLARE current_user_id INT;

    -- Ambil ID user yang melakukan aksi berdasarkan USER()
    SELECT id INTO current_user_id FROM users WHERE email = SUBSTRING_INDEX(USER(), '@', 1) LIMIT 1;

    -- Jika user bukan admin dan mencoba hapus server milik orang lain, blokir
    IF current_user_id != @OWNER_ID AND OLD.owner_id != current_user_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '❌ Tidak boleh hapus server orang lain!';
    END IF;
END$$
DELIMITER ;
-- ** Proteksi Edit User: Versi yang Anda inginkan (dengan catatan di atas) **
DROP TRIGGER IF EXISTS enforce_edit_user_by_id;
DELIMITER $$
CREATE TRIGGER enforce_edit_protection
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    DECLARE user_id INT;
    -- Set session variable
    SET @ptero_user_id = OLD.id;

    -- Retrieve the user ID from the session variable
    SELECT @ptero_user_id INTO user_id;

    -- Block the update if the user ID is not 1
    IF user_id != 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '❌ Hanya Superadmin (ID=1) yang bisa mengedit user!';
    END IF;
END$$
DELIMITER ;

-- Proteksi edit node (mutlak)
DROP TRIGGER IF EXISTS prevent_update_node;
DELIMITER $$
CREATE TRIGGER prevent_update_node
BEFORE UPDATE ON nodes
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '❌ Edit Node dilarang!';
END$$
DELIMITER ;

SQL

echo "✅ Proteksi berhasil dipasang. Skrip selesai."
