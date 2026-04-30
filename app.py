from flask import Flask, render_template, request, session, redirect, url_for, flash, make_response
import uuid
import mysql.connector
from dotenv import load_dotenv
import os
from mysql.connector import cursor
from werkzeug.utils import secure_filename
from flask_sqlalchemy import SQLAlchemy

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'dev_secret_key')

# 2. Cấu hình thư mục upload
UPLOAD_FOLDER = os.path.join(app.root_path, 'static/uploads/topics')
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME')
    )

@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        device_id = request.cookies.get('device_id')
        #Neu thiet bi la -> tao id moi
        if not device_id:
            device_id = str(uuid.uuid4())

        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)

            # Fetch user from db
            cursor.execute("SELECT ua_id, ua_username FROM User_acc WHERE ua_username = %s AND ua_password = SHA2(%s, 256)", (username, password))
            user = cursor.fetchone()

            if user:
                user_id = user['ua_id']

                try:
                    cursor.execute("SELECT 1 FROM User_Session WHERE user_id = %s AND device_id = %s", (user_id, device_id))
                    session_exists = cursor.fetchone()

                    if not session_exists:
                        cursor.execute("INSERT INTO User_Session (user_id, device_id) VALUES (%s, %s)", (user_id, device_id))
                        conn.commit()
                except mysql.connector.Error as err:
                    if err.sqlstate == '45000':
                        flash('Tài khoản đã đăng nhập trên 3 thiết bị. Vui lòng đăng xuất ở thiết bị khác!', 'danger')
                        return render_template('login.html')
                    else:
                        raise err

                session['user_id'] = user_id
                session['username'] = user['ua_username']
                session['device_id'] = device_id

                # Determine role based on database tables
                role = None
                cursor.execute("SELECT id FROM Admin WHERE id = %s", (user_id,))
                if cursor.fetchone():
                    role = "Admin"
                else:
                    cursor.execute("SELECT id FROM Lecturer WHERE id = %s", (user_id,))
                    if cursor.fetchone():
                        role = "Lecturer"
                    else:
                        cursor.execute("SELECT id FROM Student WHERE id = %s", (user_id,))
                        if cursor.fetchone():
                            role = "Student"

                if role:
                    session['role'] = role
                    flash(f'Successfully logged in as {username} ({role})!', 'success')

                    if role == 'Admin':
                        response = make_response(redirect(url_for('user_management')))
                    elif role == 'Lecturer':
                        response = make_response(redirect(url_for('lecturer_dashboard')))
                    else:
                        response = make_response(redirect(url_for('student_dashboard')))

                    response.set_cookie('device_id', device_id, max_age=31536000, httponly=True)
                    return response
                else:
                    flash('User role could not be determined.', 'danger')
            else:
                flash('Invalid username or password.', 'danger')
        except mysql.connector.Error as err:
            flash(f"Database Error: {err}", 'danger')
        finally:
            if 'cursor' in locals(): cursor.close()
            if 'conn' in locals() and conn.is_connected(): conn.close()

    return render_template('login.html')

@app.route('/logout')
def logout():
    user_id = session.get('user_id')
    device_id = session.get('device_id')
    if user_id and device_id:
        try:
            conn = get_db_connection()
            cursor = conn.cursor()

            query = "DELETE FROM User_Session WHERE user_id = %s AND device_id = %s"
            cursor.execute(query, (user_id, device_id))
            conn.commit()
        except mysql.connector.Error as err:
            print(f"Lỗi khi xóa session: {err}")
        finally:
            if 'cursor' in locals(): cursor.close()
            if 'conn' in locals() and conn.is_connected(): conn.close()

    session.clear()
    flash('Logged out successfully.', 'info')
    return redirect(url_for('login'))

@app.route('/dashboard')
def dashboard():
    # Keep route just in case some templates still link here
    if 'user_id' not in session:
        return redirect(url_for('login'))

    role = session.get('role')
    if role == 'Admin':
        return redirect(url_for('user_management'))
    elif role == 'Lecturer':
        return redirect(url_for('lecturer_dashboard'))
    else:
        return redirect(url_for('student_dashboard'))

@app.route('/lecturer/dashboard')
def lecturer_dashboard():
    if 'user_id' not in session or session.get('role') != 'Lecturer':
        return redirect(url_for('login'))

    user_id = session.get('user_id')
    user_info = None
    active_classes_count = 0
    courses = []

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        query_profile = """
            SELECT u.firstName, u.lastName, u.email, u.sex, u.birthday, l.l_msgv AS l_id, l.degree AS department
            FROM User u
            JOIN Lecturer l ON u.id = l.id
            WHERE u.id = %s
        """
        cursor.execute(query_profile, (user_id,))
        user_info = cursor.fetchone()

        query_courses = """
            SELECT
                c.class_id,
                c.class_name,
                sub.subject_name,
                sem.semester_id,
                sem.semester_start,
                sem.semester_end,
                st.status_display,
                (SELECT COUNT(*) FROM Enrollment e WHERE e.class_id = c.class_id) AS student_count
            FROM Class c
            JOIN Subject sub ON sub.subject_id = c.subject_id
            JOIN Semester sem ON sem.semester_id = c.semester_id
            JOIN Status st ON st.status_id = c.status_id
            WHERE c.lecturer_id = %s
            ORDER BY sem.semester_start DESC, c.class_id ASC
        """
        cursor.execute(query_courses, (user_id,))
        courses = cursor.fetchall()
        active_classes_count = len(courses)

    except mysql.connector.Error as e:
        flash(f"Database error: {e}", "danger")
    finally:
        if 'cursor' in locals(): cursor.close()
        if 'conn' in locals() and conn.is_connected(): conn.close()

    return render_template('lecturer_dashboard.html',
                           user_info=user_info,
                           active_classes_count=active_classes_count,
                           courses=courses)

@app.route('/lecturer/stats', methods=['GET', 'POST'])
def lecturer_stats():
    if 'user_id' not in session or session.get('role') not in ['Lecturer', 'Admin']:
        return redirect(url_for('login'))

    students_data = []
    stats_data = []
    classes_data = []
    error_msg = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        if session.get('role') == 'Lecturer': # Chỉ lấy lớp của lecturer hiện tại
            cursor.execute("""
                SELECT class_id, class_name
                FROM Class
                WHERE lecturer_id = %s
            """, (session['user_id'],))
        else:
            # Admin → xem tất cả lớp
            cursor.execute("""
                SELECT class_id, class_name
                FROM Class
            """)
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

    return render_template(
        'lecturer_stats.html',
        students_data=students_data,
        stats_data=stats_data,
        classes_data=classes_data,
        error_msg=error_msg
    )

@app.route('/student/dashboard')
def student_dashboard():
    if 'user_id' not in session or session.get('role') != 'Student':
        return redirect(url_for('login'))

    user_id = session.get('user_id')
    user_info = None
    gpa = 0.0
    courses = []

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        query_profile = """
            SELECT u.firstName, u.lastName, u.email, u.sex, u.birthday, s.s_mssv
            FROM User u
            JOIN Student s ON u.id = s.id
            WHERE u.id = %s
        """
        cursor.execute(query_profile, (user_id,))
        user_info = cursor.fetchone()

        try:
            cursor.execute("SELECT fn_MaxScore_Student_Test(%s, %s) AS gpa", (user_id, 1))
            gpa_result = cursor.fetchone()
            if gpa_result and gpa_result["gpa"] is not None:
                gpa = gpa_result["gpa"]
        except mysql.connector.Error as e:
            print(f"GPA Calculation Error: {e}")
            gpa = "N/A"

        query_courses = """
            SELECT
                c.class_id,
                c.class_name,
                sub.subject_name,
                sub.credit,
                sem.semester_id,
                sem.semester_start,
                sem.semester_end,
                st.status_display,
                CONCAT_WS(' ', lu.lastName, lu.middleName, lu.firstName) AS lecturer_name
            FROM Enrollment e
            JOIN Class c ON c.class_id = e.class_id
            JOIN Subject sub ON sub.subject_id = c.subject_id
            JOIN Semester sem ON sem.semester_id = c.semester_id
            JOIN Status st ON st.status_id = c.status_id
            LEFT JOIN Lecturer l ON l.id = c.lecturer_id
            LEFT JOIN User lu ON lu.id = l.id
            WHERE e.student_id = %s
            ORDER BY sem.semester_start DESC, c.class_id ASC
        """
        cursor.execute(query_courses, (user_id,))
        courses = cursor.fetchall()

    except mysql.connector.Error as e:
        flash(f"Database error: {e}", "danger")
    finally:
        if 'cursor' in locals(): cursor.close()
        if 'conn' in locals() and conn.is_connected(): conn.close()

    return render_template('student_dashboard.html',
                           user_info=user_info,
                           gpa=gpa,
                           courses=courses)

@app.route('/admin/users')
def user_management():
    if 'user_id' not in session or session.get('role') != 'Admin':
        flash("Unauthorized access. Only Admins can manage users.", "danger")
        return redirect(url_for('login'))

    conn = get_db_connection()
    if not conn:
        flash("Database connection failed.", "danger")
        return redirect(url_for('login'))

    cursor = None
    users = []
    pagination = {"page": 1, "per_page": 10, "total": 0, "pages": 1}
    filters = {"q": "", "role": "All"}

    try:
        cursor = conn.cursor(dictionary=True)

        q = (request.args.get("q") or "").strip()
        role_filter = (request.args.get("role") or "All").strip()
        page = request.args.get("page", "1")
        per_page = request.args.get("per_page", "10")
        try:
            page = max(1, int(page))
        except ValueError:
            page = 1
        try:
            per_page = int(per_page)
        except ValueError:
            per_page = 10
        per_page = 10 if per_page not in (10, 20, 50) else per_page

        filters = {"q": q, "role": role_filter}

        where = ["1=1"]
        params = []

        if q:
            where.append(
                "(u.email LIKE %s OR u.firstName LIKE %s OR u.middleName LIKE %s OR u.lastName LIKE %s OR s.s_mssv LIKE %s OR l.l_msgv LIKE %s OR a.a_msqt LIKE %s)"
            )
            like = f"%{q}%"
            params.extend([like, like, like, like, like, like, like])

        if role_filter == "Student":
            where.append("s.s_mssv IS NOT NULL")
        elif role_filter == "Lecturer":
            where.append("l.l_msgv IS NOT NULL")
        elif role_filter == "Admin":
            where.append("a.a_msqt IS NOT NULL")

        where_sql = " AND ".join(where)

        cursor.execute(
            f"""
            SELECT COUNT(*) AS total
            FROM User u
            LEFT JOIN Student s ON u.id = s.id
            LEFT JOIN Lecturer l ON u.id = l.id
            LEFT JOIN Admin a ON u.id = a.id
            WHERE {where_sql}
            """,
            tuple(params),
        )
        total = cursor.fetchone()["total"]

        pages = max(1, (total + per_page - 1) // per_page)
        if page > pages:
            page = pages
        offset = (page - 1) * per_page
        pagination = {"page": page, "per_page": per_page, "total": total, "pages": pages}

        cursor.execute(
            f"""
            SELECT u.id, u.firstName, u.middleName, u.lastName, u.sex, u.email, u.birthday, u.nationality,
                   s.s_mssv, l.l_msgv, l.degree AS l_degree, a.a_msqt, a.degree AS a_degree
            FROM User u
            LEFT JOIN Student s ON u.id = s.id
            LEFT JOIN Lecturer l ON u.id = l.id
            LEFT JOIN Admin a ON u.id = a.id
            WHERE {where_sql}
            ORDER BY u.id DESC
            LIMIT %s OFFSET %s
            """,
            tuple(params) + (per_page, offset),
        )
        results = cursor.fetchall()

        for row in results:
            role = "Unknown"
            user_code = ""
            degree = ""

            if row["s_mssv"]:
                role = "Student"
                user_code = row["s_mssv"]
            elif row["l_msgv"]:
                role = "Lecturer"
                user_code = row["l_msgv"]
                degree = row["l_degree"]
            elif row["a_msqt"]:
                role = "Admin"
                user_code = row["a_msqt"]
                degree = row["a_degree"]

            users.append(
                {
                    "id": row["id"],
                    "firstName": row["firstName"],
                    "middleName": row["middleName"] or "",
                    "lastName": row["lastName"],
                    "sex": row["sex"],
                    "email": row["email"],
                    "birthday": row["birthday"].strftime("%Y-%m-%d") if row["birthday"] else "",
                    "nationality": row["nationality"] or "",
                    "role": role,
                    "user_code": user_code,
                    "degree": degree,
                }
            )

    except mysql.connector.Error as e:
        flash(f"Database error: {e}", "danger")
    finally:
        if 'cursor' in locals() and cursor: cursor.close()
        if 'conn' in locals() and conn and conn.is_connected(): conn.close()

    return render_template('user_management.html',
                           filters=filters,
                           pagination=pagination,
                           users=users)

@app.route('/class/<int:class_id>')
def class_detail(class_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))

    class_info = None
    students = []
    questions = []
    tests = [] # Khởi tạo danh sách bài test rỗng
    chapters = []
    topics = []

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # 1. Lấy thông tin chung của lớp
        cursor.execute(
            """
            SELECT
                c.class_id, c.class_name, sub.subject_name, sub.credit,
                sem.semester_id, sem.semester_start, sem.semester_end,
                st.status_display,
                CONCAT_WS(' ', lu.lastName, lu.middleName, lu.firstName) AS lecturer_name
            FROM Class c
            JOIN Subject sub ON sub.subject_id = c.subject_id
            JOIN Semester sem ON sem.semester_id = c.semester_id
            JOIN Status st ON st.status_id = c.status_id
            LEFT JOIN Lecturer l ON l.id = c.lecturer_id
            LEFT JOIN User lu ON lu.id = l.id
            WHERE c.class_id = %s
            """,
            (class_id,)
        )
        class_info = cursor.fetchone()

        if not class_info:
            flash('Class not found.', 'warning')
            return redirect(url_for('dashboard'))

        cursor.execute("SELECT * FROM File WHERE class_id = %s", (class_id,))
        all_files = cursor.fetchall()

        # 2. Lay danh sach chapters
        cursor.execute("SELECT * FROM Chapter WHERE class_id = %s ORDER BY chapter_id", (class_id,))
        chapters = cursor.fetchall()

        # 3. Lay danh sach topics
        cursor.execute("SELECT * FROM Topic WHERE class_id =%s ORDER BY topic_id", (class_id,))
        topics = cursor.fetchall()

        # 4. Lấy danh sách sinh viên
        cursor.execute(
            """
            SELECT u.id, u.firstName, u.middleName, u.lastName, u.email, s.s_mssv
            FROM Enrollment e
            JOIN User u ON u.id = e.student_id
            LEFT JOIN Student s ON s.id = u.id
            WHERE e.class_id = %s
            ORDER BY u.lastName, u.firstName
            """,
            (class_id,)
        )
        students = cursor.fetchall()

        # 5. Lấy Ngân hàng câu hỏi (Chỉ dành cho Giảng viên)
        if session.get('role') == 'Lecturer':
            cursor.execute("SELECT question_id, question_type, question_content, max_score FROM Question")
            questions = cursor.fetchall()

        # 6. LẤY DANH SÁCH BÀI TEST CHỖ NÀY NÈ!
        cursor.execute(
            "SELECT test_id, test_name, test_start, test_end, test_timer FROM Test WHERE class_id = %s ORDER BY test_start DESC",
            (class_id,)
        )
        tests = cursor.fetchall()

    except mysql.connector.Error as e:
        flash(f"Database error: {e}", "danger")
    finally:
        if 'cursor' in locals() and cursor:
            cursor.close()
        if 'conn' in locals() and conn and conn.is_connected():
            conn.close()

    # TRUYỀN BIẾN tests VÀO ĐÂY LÀ LÊN HÌNH NGAY!
    return render_template('class_detail.html', class_info=class_info, students=students, questions=questions, tests=tests, chapters=chapters, topics=topics, all_files=all_files)

@app.route('/admin/users/create', methods=['POST'])
def create_user():
    if "user_id" not in session or session.get("role") != "Admin":
        return redirect(url_for("login"))

    conn = get_db_connection()
    if not conn:
        return redirect(url_for("user_management"))

    cursor = None
    try:
        cursor = conn.cursor()

        role = (request.form.get("role") or "").strip()
        first_name = (request.form.get("firstName") or "").strip()
        middle_name = (request.form.get("middleName") or "").strip()
        last_name = (request.form.get("lastName") or "").strip()
        sex = (request.form.get("sex") or "").strip()
        email = (request.form.get("email") or "").strip()
        birthday = (request.form.get("birthday") or "").strip() or None
        nationality = (request.form.get("nationality") or "").strip()
        user_code = (request.form.get("userCode") or "").strip()
        degree = (request.form.get("degree") or "").strip()

        if role not in ("Student", "Lecturer", "Admin"):
            flash("Invalid role.", "danger")
            return redirect(url_for("user_management"))
        if sex not in ("Male", "Female", "Other"):
            flash("Invalid sex value.", "danger")
            return redirect(url_for("user_management"))
        if not email.endswith("@hcmut.edu.vn"):
            flash("Email must end with @hcmut.edu.vn.", "danger")
            return redirect(url_for("user_management"))
        if not user_code:
            flash("User code is required.", "danger")
            return redirect(url_for("user_management"))
        if role in ("Lecturer", "Admin") and degree not in ("Bachelor", "Master", "PhD"):
            flash("Degree is required for Lecturer/Admin.", "danger")
            return redirect(url_for("user_management"))

        args = (role, first_name, middle_name, last_name, sex, email, birthday, nationality, user_code, degree, 0)
        cursor.callproc("sp_CreateUser", args)

        conn.commit()
        flash("User created successfully!", "success")

    except mysql.connector.Error as e:
        conn.rollback()
        flash(f"{e.msg}", "danger")
    finally:
        if cursor:
            cursor.close()
        if conn.is_connected():
            conn.close()

    return redirect(url_for("user_management"))

@app.route('/admin/users/update', methods=['POST'])
def update_user():
    if "user_id" not in session or session.get("role") != "Admin":
        return redirect(url_for("login"))

    conn = get_db_connection()
    if not conn:
        return redirect(url_for("user_management"))

    cursor = None
    try:
        cursor = conn.cursor()

        user_id_raw = (request.form.get("user_id") or "").strip()
        try:
            user_id = int(user_id_raw)
        except ValueError:
            flash("Invalid user id.", "danger")
            return redirect(url_for("user_management"))

        first_name = (request.form.get("firstName") or "").strip()
        middle_name = (request.form.get("middleName") or "").strip()
        last_name = (request.form.get("lastName") or "").strip()
        sex = (request.form.get("sex") or "").strip()
        email = (request.form.get("email") or "").strip()
        birthday = (request.form.get("birthday") or "").strip() or None
        nationality = (request.form.get("nationality") or "").strip()

        if sex not in ("Male", "Female", "Other"):
            flash("Invalid sex value.", "danger")
            return redirect(url_for("user_management"))
        if not email.endswith("@hcmut.edu.vn"):
            flash("Email must end with @hcmut.edu.vn.", "danger")
            return redirect(url_for("user_management"))

        args = (user_id, first_name, middle_name, last_name, sex, email, birthday, nationality)
        cursor.callproc("sp_UpdateUserInfo", args)

        conn.commit()
        flash("User updated successfully!", "success")

    except mysql.connector.Error as e:
        conn.rollback()
        flash(f"{e.msg}", "danger")
    finally:
        if cursor:
            cursor.close()
        if conn.is_connected():
            conn.close()

    return redirect(url_for("user_management"))

@app.route('/admin/users/change-password', methods=['POST'])
def change_password():
    if "user_id" not in session or session.get("role") != "Admin":
        return redirect(url_for("login"))

    conn = get_db_connection()
    if not conn:
        return redirect(url_for("user_management"))

    cursor = None
    try:
        cursor = conn.cursor()

        user_id_raw = (request.form.get("user_id") or "").strip()
        try:
            user_id = int(user_id_raw)
        except ValueError:
            flash("Invalid user id.", "danger")
            return redirect(url_for("user_management"))

        old_password = request.form.get("oldPassword") or ""
        new_password = request.form.get("newPassword") or ""
        if not old_password or not new_password:
            flash("Passwords cannot be empty.", "danger")
            return redirect(url_for("user_management"))

        args = (user_id, old_password, new_password)
        cursor.callproc("sp_ChangePassword", args)

        conn.commit()
        flash("Password changed successfully!", "success")

    except mysql.connector.Error as e:
        conn.rollback()
        flash(f"{e.msg}", "danger")
    finally:
        if cursor:
            cursor.close()
        if conn.is_connected():
            conn.close()

    return redirect(url_for("user_management"))

@app.route('/admin/users/delete', methods=['POST'])
def delete_user():
    if "user_id" not in session or session.get("role") != "Admin":
        return redirect(url_for("login"))

    conn = get_db_connection()
    if not conn:
        return redirect(url_for("user_management"))

    cursor = None
    try:
        cursor = conn.cursor()

        user_id_raw = (request.form.get("user_id") or "").strip()
        try:
            user_id = int(user_id_raw)
        except ValueError:
            flash("Invalid user id.", "danger")
            return redirect(url_for("user_management"))

        cursor.callproc("sp_DeleteUser", (user_id,))
        conn.commit()
        flash("User deleted successfully!", "success")

    except mysql.connector.Error as e:
        conn.rollback()
        flash(f"{e.msg}", "danger")
    finally:
        if cursor:
            cursor.close()
        if conn.is_connected():
            conn.close()

    return redirect(url_for("user_management"))

@app.route('/class/<int:class_id>/discussion')
def discussion_list(class_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))

    posts = []
    class_name = f'Class {class_id}'
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT class_name FROM Class WHERE class_id = %s", (class_id,))
        class_row = cursor.fetchone()
        if class_row:
            class_name = class_row['class_name']

        cursor.execute(
            """
            SELECT p.post_id,
                   p.post_name,
                   p.post_description,
                   p.post_start,
                   CONCAT_WS(' ', u.lastName, u.middleName, u.firstName) AS author_name,
                   COUNT(c.comment_id) AS comment_count
            FROM Post p
            JOIN User_acc ua ON p.ua_id = ua.ua_id
            JOIN User u ON ua.ua_id = u.id
            LEFT JOIN Comment c ON c.post_id = p.post_id
            WHERE p.class_id = %s
            GROUP BY p.post_id
            ORDER BY p.post_start DESC
            """,
            (class_id,)
        )
        posts = cursor.fetchall()
    except mysql.connector.Error as e:
        flash(f"Database error: {e}", "danger")
    finally:
        if 'cursor' in locals() and cursor:
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

    return render_template('discussion_list.html', class_id=class_id, class_name=class_name, posts=posts, can_create_post=True)

@app.route('/class/<int:class_id>/discussion/new', methods=['GET', 'POST'])
def discussion_create_post(class_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))

    if request.method == 'POST':
        post_name = (request.form.get('post_name') or '').strip()
        post_description = (request.form.get('post_description') or '').strip()

        if not post_name:
            flash('Post title is required.', 'danger')
            return redirect(url_for('discussion_create_post', class_id=class_id))

        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO Post (post_name, post_description, post_start, ua_id, class_id) VALUES (%s, %s, NOW(), %s, %s)",
                (post_name, post_description, session['user_id'], class_id),
            )
            conn.commit()
            flash('Post created successfully.', 'success')
        except mysql.connector.Error as e:
            if conn and conn.is_connected():
                conn.rollback()
            flash(f"Database error: {e}", 'danger')
        finally:
            if 'cursor' in locals() and cursor:
                cursor.close()
            if 'conn' in locals() and conn and conn.is_connected():
                conn.close()

        return redirect(url_for('discussion_list', class_id=class_id))

    return render_template('discussion_create_post.html', class_id=class_id, class_name=f'Class {class_id}')

@app.route('/discussion/post/<int:post_id>')
def discussion_post_detail(post_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))

    post = None
    comments = []

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT p.post_id,
                   p.post_name,
                   p.post_description,
                   p.post_start,
                   p.class_id,
                   c.class_name,
                   CONCAT_WS(' ', u.lastName, u.middleName, u.firstName) AS author_name
            FROM Post p
            JOIN Class c ON p.class_id = c.class_id
            JOIN User_acc ua ON p.ua_id = ua.ua_id
            JOIN User u ON ua.ua_id = u.id
            WHERE p.post_id = %s
            """,
            (post_id,),
        )
        post = cursor.fetchone()
        if not post:
            flash('The requested discussion post does not exist.', 'warning')
            return redirect(url_for('dashboard'))

        cursor.execute(
            """
            SELECT cm.comment_id,
                   cm.comment_content AS comment_content,
                   cm.comment_start,
                   CONCAT_WS(' ', u.lastName, u.middleName, u.firstName) AS author_name
            FROM Comment cm
            JOIN User_acc ua ON cm.ua_id = ua.ua_id
            JOIN User u ON ua.ua_id = u.id
            WHERE cm.post_id = %s
            ORDER BY cm.comment_start ASC
            """,
            (post_id,),
        )
        comments = cursor.fetchall()

    except mysql.connector.Error as e:
        flash(f"Database error: {e}", "danger")
    finally:
        if 'cursor' in locals() and cursor:
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

    return render_template(
        'discussion_post_detail.html',
        class_id=post['class_id'],
        class_name=post['class_name'],
        post=post,
        comments=comments,
        can_comment=True,
    )

@app.route('/discussion/post/<int:post_id>/comment', methods=['POST'])
def discussion_add_comment(post_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))

    content = (request.form.get('comment_content') or '').strip()
    if not content:
        flash('Comment content cannot be empty.', 'danger')
        return redirect(url_for('discussion_post_detail', post_id=post_id))

    user_id = session['user_id']
    role = session.get('role')

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # --- XỬ LÝ RÀNG BUỘC 3: KIỂM TRA QUYỀN BÌNH LUẬN ---
        if role == 'Student':
            cursor.execute("""
                SELECT e.is_allowed_to_discuss 
                FROM Enrollment e 
                JOIN Post p ON p.class_id = e.class_id 
                WHERE p.post_id = %s AND e.student_id = %s
            """, (post_id, user_id))
            enrollment = cursor.fetchone()

            if not enrollment:
                flash('Bạn không thuộc lớp học này nên không thể bình luận!', 'danger')
                return redirect(url_for('dashboard'))

            if not enrollment['is_allowed_to_discuss']:
                flash('Bạn đã bị giảng viên khóa quyền bình luận trong lớp này!', 'danger')
                return redirect(url_for('discussion_post_detail', post_id=post_id))
        # --------------------------------------------------

        cursor.execute(
            "INSERT INTO Comment (comment_content, post_id, ua_id) VALUES (%s, %s, %s)",
            (content, post_id, user_id),
        )
        conn.commit()
        flash('Comment posted successfully.', 'success')
    except mysql.connector.Error as e:
        if conn and conn.is_connected():
            conn.rollback()
        flash(f"Database error: {e}", 'danger')
    finally:
        if 'cursor' in locals() and cursor:
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

    return redirect(url_for('discussion_post_detail', post_id=post_id))

@app.route('/class/<int:class_id>/test/create', methods=['POST'])
def create_test(class_id):
    if 'user_id' not in session or session.get('role') != 'Lecturer':
        flash('Chỉ giảng viên mới có quyền tạo bài kiểm tra.', 'danger')
        return redirect(url_for('dashboard'))

    test_name = request.form.get('test_name')
    test_start = request.form.get('test_start')
    test_end = request.form.get('test_end')
    test_timer = request.form.get('test_timer')
    chapter_id = request.form.get('chapter_id') or None

    question_ids = request.form.getlist('question_ids')

    if not question_ids:
        flash('Một bài kiểm tra phải có ít nhất một câu hỏi!', 'danger')
        return redirect(url_for('class_detail', class_id=class_id))

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT lecturer_id FROM Class WHERE class_id = %s", (class_id,))
        class_info = cursor.fetchone()

        if not class_info or class_info['lecturer_id'] != session['user_id']:
            flash('Bạn không có quyền quản lý hay tạo bài thi cho lớp học này!', 'danger')
            return redirect(url_for('dashboard'))

        # KHÔNG GỌI conn.start_transaction() NỮA VÌ NÓ ĐÃ TỰ START KHI CHẠY CÂU SELECT Ở TRÊN!

        cursor.execute("""
            INSERT INTO Test (test_name, test_start, test_end, test_timer, class_id, chapter_id) 
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (test_name, test_start, test_end, test_timer, class_id, chapter_id))

        new_test_id = cursor.lastrowid

        for q_id in question_ids:
            cursor.execute("""
                INSERT INTO Test_Question (test_id, question_id) 
                VALUES (%s, %s)
            """, (new_test_id, q_id))

        conn.commit()
        flash('Tạo bài kiểm tra thành công!', 'success')

    except mysql.connector.Error as e:
        if conn and conn.is_connected():
            conn.rollback()
        flash(f"Lỗi cơ sở dữ liệu: {e}", 'danger')
    finally:
        if 'cursor' in locals() and cursor: cursor.close()
        if 'conn' in locals() and conn.is_connected(): conn.close()

    return redirect(url_for('class_detail', class_id=class_id))

@app.route('/class/<int:class_id>/chapter/add', methods=['GET', 'POST'])
def add_chapter(class_id):
    if session.get('role') != ('Lecturer'):
        flash('Bạn không có quyền thêm chương học!', 'danger')
        return redirect(url_for('login'))

    if request.method == 'POST':
        chapter_name = request.form.get('chapter_name')
        description = request.form.get('description')

        if not chapter_name:
            flash('Tên chương không được để trống!', 'warning')
            return redirect(request.url)
        try:
            conn = get_db_connection()
            cursor = conn.cursor()

            cursor.execute("SELECT COALESCE(MAX(chapter_id), 0) + 1 FROM Chapter WHERE class_id =%s", (class_id,))
            next_chapter_id = cursor.fetchone()[0]

            query = "INSERT INTO Chapter (class_id, chapter_id, chapter_name, description) VALUES (%s, %s, %s, %s)"
            cursor.execute(query, (class_id, next_chapter_id, chapter_name, description))

            conn.commit()
            flash(f'Đã thêm chương {next_chapter_id}: {chapter_name}', 'success')

            return redirect(url_for('class_detail', class_id=class_id))

        except mysql.connector.Error as err:
            flash(f'Lỗi database: {err}', 'danger')
        finally:
            if 'conn' in locals() and conn.is_connected():
                conn.close()

    return render_template('Chapter_form.html', class_id=class_id)


UPLOAD_FOLDER = 'static/uploads/topics'
ALLOWED_EXTENSIONS = {'pdf', 'docx', 'pptx', 'zip', 'jpg', 'png'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Tạo thư mục nếu chưa có
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def get_file_size(file_storage):
    """Tính kích thước file theo MB"""
    file_storage.seek(0, os.SEEK_END)
    size_bytes = file_storage.tell()
    file_storage.seek(0) # Reset con trỏ sau khi đo
    return round(size_bytes / (1024 * 1024), 2)


@app.route('/class/<int:class_id>/chapter/<int:chapter_id>/add_topic', methods=['GET', 'POST'])
def add_topic(class_id, chapter_id):
    if 'user_id' not in session or session.get('role') != 'Lecturer':
        flash("Bạn không có quyền thực hiện thao tác này.", "danger")
        return redirect(url_for('login'))

    if request.method == 'POST':
        topic_name = request.form.get('topic_name')
        content = request.form.get('content')
        uploaded_file = request.files.get('file')

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        try:
            # 1. Tính toán topic_id mới (Lấy Max toàn bảng để đảm bảo tính duy nhất Global)
            cursor.execute("SELECT COALESCE(MAX(topic_id), 0) + 1 as next_id FROM Topic")
            new_topic_id = cursor.fetchone()['next_id']

            # 2. Lưu vào bảng Topic (Đủ 5 cột theo schema của bạn)
            # Schema: (class_id, chapter_id, topic_id, topic_name, topic_content)
            cursor.execute(
                """INSERT INTO Topic (class_id, chapter_id, topic_id, topic_name, topic_content)
                   VALUES (%s, %s, %s, %s, %s)""",
                (class_id, chapter_id, new_topic_id, topic_name, content)
            )

            # 3. Xử lý File đính kèm ngay khi tạo Topic (nếu có)
            if uploaded_file and uploaded_file.filename != '':
                filename = secure_filename(uploaded_file.filename)
                # Đổi tên file vật lý để tránh trùng (Dùng t{id}_ làm prefix)
                save_filename = f"t{new_topic_id}_{filename}"

                # Lưu file tạm để tính dung lượng
                file_path = os.path.join(app.config['UPLOAD_FOLDER'], save_filename)
                uploaded_file.save(file_path)
                file_size_mb = round(os.path.getsize(file_path) / (1024 * 1024), 2)

                # Kiểm tra ràng buộc CHECK của Database (0 < size <= 200)
                if 0 < file_size_mb <= 200:
                    cursor.execute(
                        """INSERT INTO File (class_id, chapter_id, topic_id, file_id, file_name, file_path, file_size)
                           VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                        (class_id, chapter_id, new_topic_id, 1, filename, save_filename, file_size_mb)
                    )
                else:
                    os.remove(file_path)  # Xóa file nếu vi phạm dung lượng
                    flash("File phải > 0MB và <= 200MB", "warning")

            conn.commit()
            flash("Thêm bài học thành công!", "success")
            return redirect(url_for('class_detail', class_id=class_id))

        except Exception as e:
            conn.rollback()
            flash(f"Lỗi Database: {e}", "danger")
        finally:
            cursor.close()
            conn.close()

    return render_template('add_topic.html', class_id=class_id, chapter_id=chapter_id)


@app.route('/upload_file/<int:topic_id>', methods=['GET', 'POST'])
def upload_topic_file(topic_id):
    # 1. Kiểm tra quyền Lecturer
    if session.get('role') != 'Lecturer':
        flash("Bạn không có quyền thực hiện thao tác này!", "danger")
        return redirect(url_for('index'))

    if request.method == 'POST':
        file = request.files.get('file')

        if not file or file.filename == '':
            flash("Vui lòng chọn một file!", "warning")
            return redirect(request.referrer)

        conn = get_db_connection()
        # Sử dụng buffered=True để tránh lỗi đồng bộ kết quả truy vấn
        cursor = conn.cursor(dictionary=True, buffered=True)

        try:
            # 2. Quan trọng: Lấy đầy đủ bộ khóa (class_id, chapter_id) từ Topic
            # Vì bảng File yêu cầu 3 cột này để thỏa mãn Foreign Key
            cursor.execute(
                "SELECT class_id, chapter_id FROM Topic WHERE topic_id = %s",
                (topic_id,)
            )
            topic_data = cursor.fetchone()

            if not topic_data:
                flash("Lỗi: Không tìm thấy bài học này!", "danger")
                return redirect(request.referrer)

            c_id = topic_data['class_id']
            chap_id = topic_data['chapter_id']

            # 3. Xử lý file vật lý
            filename = secure_filename(file.filename)
            # Tạo tên file duy nhất để tránh ghi đè: t[id]_[filename]
            save_filename = f"t{topic_id}_{filename}"

            if not os.path.exists(app.config['UPLOAD_FOLDER']):
                os.makedirs(app.config['UPLOAD_FOLDER'])

            file_save_path = os.path.join(app.config['UPLOAD_FOLDER'], save_filename)
            file.save(file_save_path)

            # Tính dung lượng thực tế (MB)
            file_size = round(os.path.getsize(file_save_path) / (1024 * 1024), 2)

            # 4. Kiểm tra ràng buộc CHECK của Database (0 < size <= 200)
            if file_size <= 0 or file_size > 200:
                if os.path.exists(file_save_path):
                    os.remove(file_save_path)  # Xóa file lỗi
                flash("File phải có dung lượng từ 0 - 200MB!", "danger")
                return redirect(request.referrer)

            # 5. Tính file_id mới (Tự tăng trong bộ 3 khóa chính của Topic đó)
            cursor.execute("""
                           SELECT COALESCE(MAX(file_id), 0) + 1 as next_id
                           FROM File
                           WHERE class_id = %s
                             AND chapter_id = %s
                             AND topic_id = %s
                           """, (c_id, chap_id, topic_id))
            next_file_id = cursor.fetchone()['next_id']

            # 6. Insert vào DB - Phải khớp hoàn toàn thứ tự cột
            sql = """
                  INSERT INTO File (class_id, chapter_id, topic_id, file_id, file_name, file_path, file_size)
                  VALUES (%s, %s, %s, %s, %s, %s, %s) \
                  """
            # Lưu ý: file_path lưu save_filename (tên file đã đổi để tránh trùng)
            cursor.execute(sql, (c_id, chap_id, topic_id, next_file_id, filename, save_filename, file_size))

            conn.commit()
            flash(f"Tải lên thành công: {filename}", "success")

        except Exception as e:
            conn.rollback()
            # Xóa file nếu DB lỗi để tránh rác server
            if 'file_save_path' in locals() and os.path.exists(file_save_path):
                os.remove(file_save_path)
            flash(f"Lỗi Database: {str(e)}", "danger")
            print(f"Log lỗi: {e}")  # Debug lỗi ra console
        finally:
            cursor.close()
            conn.close()

        return redirect(request.referrer or url_for('index'))

    return render_template('upload_file.html', topic_id=topic_id)

if __name__ == '__main__':
    app.run(debug=True)
