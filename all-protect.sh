#!/bin/bash
# Anti Delete Server + User (Pterodactyl)

ENV="/var/www/pterodactyl/.env"
OWNER_ID=1

# Ambil DB info dari .env
DB_USER=$(grep DB_USERNAME $ENV | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD $ENV | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE $ENV | cut -d '=' -f2)
DB_HOST=$(grep DB_HOST $ENV | cut -d '=' -f2)

DB_HOST=${DB_HOST:-127.0.0.1}

# Pasang trigger
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME <<SQL
DROP TRIGGER IF EXISTS prevent_delete_user;
DELIMITER $$
CREATE TRIGGER prevent_delete_user
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  IF OLD.id <> $OWNER_ID THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '❌ Tidak bisa hapus Superadmin!';
  END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS prevent_delete_server;
DELIMITER $$
CREATE TRIGGER prevent_delete_server
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF OLD.owner_id <> $OWNER_ID THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '❌ Tidak boleh hapus server orang lain!';
  END IF;
END$$
DELIMITER ;
SQL

echo "✅ Proteksi berhasil dipasang!"
