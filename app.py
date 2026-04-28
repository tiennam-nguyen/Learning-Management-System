from flask import Flask, render_template, request, session, redirect, url_for, flash
import mysql.connector
from dotenv import load_dotenv
import os

def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME')
    )

app = Flask(__name__)
app.secret_key = 'dev_secret_key'

@app.context_processor
def inject_csrf(): 
    return dict(csrf_token='mock_csrf_token')

@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            
            # Fetch user from db
            cursor.execute("SELECT ua_id, ua_username FROM User_acc WHERE ua_username = %s AND ua_password = SHA2(%s, 256)", (username, password))
            user = cursor.fetchone()
            
            if user:
                user_id = user['ua_id']
                session['user_id'] = user_id
                session['username'] = user['ua_username']
                
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
                        return redirect(url_for('user_management'))
                    elif role == 'Lecturer':
                        return redirect(url_for('lecturer_dashboard'))
                    else:
                        return redirect(url_for('student_dashboard'))
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
            cursor.execute("SELECT fn_CalculateSemesterGPA(%s, %s) AS gpa", (user_id, 1))
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

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
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
            FROM Class c
            JOIN Subject sub ON sub.subject_id = c.subject_id
            JOIN Semester sem ON sem.semester_id = c.semester_id
            JOIN Status st ON st.status_id = c.status_id
            LEFT JOIN Lecturer l ON l.id = c.lecturer_id
            LEFT JOIN User lu ON lu.id = l.id
            WHERE c.class_id = %s
            """,
            (class_id,),
        )
        class_info = cursor.fetchone()

        if not class_info:
            flash('Class not found.', 'warning')
            return redirect(url_for('dashboard'))

        cursor.execute(
            """
            SELECT
                u.id,
                u.firstName,
                u.middleName,
                u.lastName,
                u.email,
                s.s_mssv
            FROM Enrollment e
            JOIN User u ON u.id = e.student_id
            LEFT JOIN Student s ON s.id = u.id
            WHERE e.class_id = %s
            ORDER BY u.lastName, u.firstName
            """,
            (class_id,),
        )
        students = cursor.fetchall()

    except mysql.connector.Error as e:
        flash(f"Database error: {e}", "danger")
    finally:
        if 'cursor' in locals() and cursor:
            cursor.close()
        if 'conn' in locals() and conn and conn.is_connected():
            conn.close()

    return render_template('class_detail.html', class_info=class_info, students=students)

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

@app.route('/index')
def landing_page():
    return render_template('index.html')

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

