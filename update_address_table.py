import sqlite3
import os

db_path = 'edu_delivery_backend/instance/edu_delivery_v2.db'

if not os.path.exists(db_path):
    db_path = 'instance/edu_delivery_v2.db'

print(f"Connecting to {db_path}...")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    print("Adding recipient_name column...")
    cursor.execute("ALTER TABLE 'address' ADD COLUMN recipient_name VARCHAR(100)")
    print("Adding recipient_phone column...")
    cursor.execute("ALTER TABLE 'address' ADD COLUMN recipient_phone VARCHAR(15)")
    conn.commit()
    print("Database updated successfully!")
except sqlite3.OperationalError as e:
    print(f"Note: {e}")
finally:
    conn.close()
