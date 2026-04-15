from flask import Flask, render_template
import mysql.connector
from dotenv import load_dotenv
import os

load_dotenv()
app = Flask(__name__)

# Hàm kết nối Database dùng chung
def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME')
    )

# Route Frontend mặc định
@app.route('/')
def index():
    try:
        conn = get_db_connection()
        conn.close()
        return render_template('index.html', message="✅ Backend đã kết nối Database thành công!")
    except Exception as e:
        return f"❌ Lỗi kết nối CSDL: {str(e)}"

if __name__ == '__main__':
    app.run(debug=True)