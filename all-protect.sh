#!/usr/bin/env bash
# protect_auto.sh
# ----------------------------------------
# Auto-detect DB name/user/password from Pterodactyl .env
# Try to create triggers to prevent deletes (except superadmin id=1)
# If DB user lacks privileges, try to GRANT via root if possible
# ----------------------------------------

set -euo pipefail

# 1) cari .env Pterodactyl
ENV_PATH="/var/www/pterodactyl/.env"
if [ ! -f "$ENV_PATH" ]; then
  echo "[+] .env default not found at $ENV_PATH"
  echo "[+] Mencari file .env lain (butuh waktu sebentar)..."
  FOUND=$(sudo find / -type f -name ".env" 2>/dev/null | grep -v "node_modules" | grep -i pterodactyl | head -n 1 || true)
  if [ -z "$FOUND" ]; then
    echo "(!) Gagal menemukan .env otomatis. Silakan jalankan script ini dengan path .env sebagai argumen:"
    echo "    sudo ./protect_auto.sh /path/to/.env"
    exit 1
  fi
  ENV_PATH="$FOUND"
  echo "[+] Ketemu .env: $ENV_PATH"
fi

# 2) baca variabel dari .env
DB_NAME=$(sudo grep -E '^DB_DATABASE=' "$ENV_PATH" 2>/dev/null | cut -d'=' -f2- | tr -d '\r' | sed 's/^"\(.*\)"$/\1/')
DB_USER=$(sudo grep -E '^DB_USERNAME=' "$ENV_PATH" 2>/dev/null | cut -d'=' -f2- | tr -d '\r' | sed 's/^"\(.*\)"$/\1/')
DB_PASS=$(sudo grep -E '^DB_PASSWORD=' "$ENV_PATH" 2>/dev/null | cut -d'=' -f2- | tr -d '\r' | sed 's/^"\(.*\)"$/\1/')

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
  echo "(!) Gagal membaca DB_DATABASE atau DB_USERNAME dari $ENV_PATH"
  echo "    Cek isi file .env atau jalankan manual."
  exit 1
fi

echo "[+] DB detected:"
echo "    DB_NAME = $DB_NAME"
echo "    DB_USER = $DB_USER"
# don't echo password for safety by default
echo "    DB_PASS = (hidden)"

# 3) buat file SQL trigger sementara
TMPSQL=$(mktemp /tmp/pterodactyl_triggers.XXXX.sql)

cat > "$TMPSQL" <<'SQL'
DELIMITER //
DROP TRIGGER IF EXISTS prevent_delete_server;
//
CREATE TRIGGER prevent_delete_server
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF (OLD.owner_id != 1) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '⚠️ Terjadi Kesalahan: Mau hapus server orang lain? harus izin boss ikhsan';
  END IF;
END;
//
DROP TRIGGER IF EXISTS prevent_delete_user;
//
CREATE TRIGGER prevent_delete_user
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  IF (OLD.id = 1) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '⚠️ Tidak bisa hapus Superadmin utama!';
  END IF;
END;
//
DELIMITER ;
SQL

# 4) fungsi bantu: coba jalankan SQL dengan user yang ada
run_with_db_user() {
  local user="$1"; local pass="$2"; local db="$3"
  if [ -z "$pass" ]; then
    mysql -u"$user" -D "$db" < "$TMPSQL" 2>&1
  else
    mysql -u"$user" -p"$pass" -D "$db" < "$TMPSQL" 2>&1
  fi
}

echo "[+] Mencoba memasang trigger menggunakan user DB ($DB_USER)..."
OUT=""
if OUT=$(run_with_db_user "$DB_USER" "$DB_PASS" "$DB_NAME"); then
  echo "✅ Trigger berhasil dibuat dengan user $DB_USER."
  rm -f "$TMPSQL"
  exit 0
else
  echo "⚠️ Gagal membuat trigger dengan user $DB_USER. Pesan error mysql:"
  echo "----START MYSQL ERROR----"
  echo "$OUT"
  echo "----END MYSQL ERROR----"
fi

# 5) kalau gagal: coba grant privileges via root (hanya jika bisa akses tanpa password)
echo "[+] Mencoba memberikan privilege TRIGGER untuk $DB_USER lewat root (jika tersedia)..."

# cek apakah mysql root tanpa password bisa dipanggil
if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
  echo "[+] Root MySQL tanpa password tersedia. Menjalankan GRANT..."
  # gunakan identificator user persis seperti di .env; jika mengandung host seperti user@host, kita perlu pisah.
  # Umumnya DB_USERNAME di .env = username (tanpa @host). Gunakan 'username'@'localhost'
  SQLGRANT="GRANT SELECT, INSERT, UPDATE, DELETE, TRIGGER ON \`$DB_NAME\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
  mysql -u root -e "$SQLGRANT"
  echo "[+] Privilege diberikan. Mencoba lagi membuat trigger..."
  if OUT=$(run_with_db_user "$DB_USER" "$DB_PASS" "$DB_NAME"); then
    echo "✅ Trigger berhasil dibuat setelah GRANT."
    rm -f "$TMPSQL"
    exit 0
  else
    echo "⚠️ Masih gagal membuat trigger meskipun sudah GRANT. Error:"
    echo "$OUT"
    rm -f "$TMPSQL"
    exit 1
  fi
else
  echo "(!) Tidak bisa auto-GRANT karena root MySQL butuh password atau tidak tersedia tanpa password."
  echo ""
  echo "Langkah manual yang harus lo lakukan (copas dan jalankan sebagai root MySQL):"
  echo ""
  echo "1) Login ke MySQL sebagai root:"
  echo "   sudo mysql -u root -p"
  echo ""
  echo "2) Setelah masuk ke mysql shell, jalankan (ganti 'DBNAME' dan 'DBUSER' jika beda):"
  echo ""
  echo "   USE \`$DB_NAME\`;"
  echo "   GRANT SELECT, INSERT, UPDATE, DELETE, TRIGGER ON \`$DB_NAME\`.* TO '${DB_USER}'@'localhost';"
  echo "   FLUSH PRIVILEGES;"
  echo ""
  echo "3) Kemudian keluar dan jalankan lagi trigger SQL (server):"
  echo "   sudo mysql -u ${DB_USER} -p${DB_PASS} -D ${DB_NAME} < $TMPSQL"
  echo ""
  echo "Catatan: kalau DB_USER terdaftar bukan sebagai 'user'@'localhost', ubah host sesuai user (cek di mysql.user)."
  rm -f "$TMPSQL"
  exit 1
fi
