from flask import Flask, render_template, request
import mysql.connector
from dotenv import load_dotenv
import os

load_dotenv()
app = Flask(__name__)

def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME')
    )

@app.route('/', methods=['GET', 'POST'])
def index():
    students_data = []
    stats_data = []
    classes_data = [] # Lưu danh sách lớp cho dropdown
    error_msg = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # LUÔN CHẠY: Lấy danh sách lớp học đổ vào Dropdown
        cursor.execute("SELECT class_id, class_name FROM Class")
        classes_data = cursor.fetchall()

        if request.method == 'POST':
            action = request.form.get('action')
            
            # --- XỬ LÝ 3.2 ---
            if action == 'search_students':
                keyword = request.form.get('keyword', '')
                cursor.callproc('sp_GetStudentsByClass', [keyword])
                for result in cursor.stored_results():
                    students_data = result.fetchall()

            # --- XỬ LÝ 3.3 ---
            elif action == 'view_stats':
                class_id = request.form.get('class_id')
                
                try:
                    min_score = float(request.form.get('min_score', 0))
                    
                    # Validate Backend: Kiểm tra điểm sàn
                    if min_score < 0 or min_score > 10:
                        error_msg = "❌ Lỗi: Điểm sàn không hợp lệ (Phải từ 0 đến 10)."
                    # Validate Backend: Kiểm tra ID lớp có tồn tại không
                    elif not any(str(c['class_id']) == str(class_id) for c in classes_data):
                        error_msg = "❌ Lỗi: Lớp học này không tồn tại trong hệ thống."
                    else:
                        cursor.callproc('sp_GetStudentTestStatsByClass', [class_id, min_score])
                        for result in cursor.stored_results():
                            stats_data = result.fetchall()
                except ValueError:
                    error_msg = "❌ Lỗi: Điểm sàn phải là một con số."

        cursor.close()
        conn.close()
        
    except Exception as e:
        error_msg = f"❌ Lỗi hệ thống: {str(e)}"

    return render_template('index.html', 
                           students_data=students_data, 
                           stats_data=stats_data,
                           classes_data=classes_data,
                           error_msg=error_msg)

if __name__ == '__main__':
    app.run(debug=True)