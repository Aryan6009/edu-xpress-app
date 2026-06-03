import sqlite3
import os

db_path = 'edu_delivery_backend/instance/edu_delivery_v2.db'

print(f"Connecting to {db_path}...")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

def add_column(table, column, type):
    try:
        print(f"Adding {column} to {table}...")
        cursor.execute(f"ALTER TABLE \"{table}\" ADD COLUMN {column} {type}")
        print("Success.")
    except sqlite3.OperationalError as e:
        print(f"Skipped: {e}")

# Product table
add_column('product', 'author', 'VARCHAR(100)')
add_column('product', 'isbn', 'VARCHAR(20)')
add_column('product', 'brand', 'VARCHAR(100)')
add_column('product', 'specifications', 'TEXT')

# ChatHistory table (might need to create it if it doesn't exist)
try:
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        reply TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user (id)
    )
    """)
    print("ChatHistory table ensured.")
except Exception as e:
    print(f"Error with ChatHistory: {e}")

conn.commit()
conn.close()
print("Migration complete.")
