import sqlite3
import os

db_path = 'edu_delivery_backend/instance/edu_delivery_v2.db'

if not os.path.exists(db_path):
    db_path = 'instance/edu_delivery_v2.db' # Fallback if run from backend dir

print(f"Connecting to {db_path}...")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    print("Adding latitude column...")
    cursor.execute("ALTER TABLE 'order' ADD COLUMN latitude FLOAT")
    print("Adding longitude column...")
    cursor.execute("ALTER TABLE 'order' ADD COLUMN longitude FLOAT")
    conn.commit()
    print("Database updated successfully!")
except sqlite3.OperationalError as e:
    print(f"Note: {e} (The columns might already exist)")
finally:
    conn.close()
