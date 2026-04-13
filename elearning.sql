-- ==========================================
-- SCRIPT KHỞI TẠO CSDL E-LEARNING (MYSQL)
-- DỰA TRÊN SƠ ĐỒ E-ERD CHUẨN XML
-- ==========================================
CREATE DATABASE IF NOT EXISTS ELearningDB;
USE ELearningDB;

-- 1. BẢNG DANH MỤC CƠ SỞ
CREATE TABLE Role (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL
);

CREATE TABLE Status (
    status_id INT AUTO_INCREMENT PRIMARY KEY,
    status_display VARCHAR(50) NOT NULL
);

CREATE TABLE Semester (
    semester_id INT AUTO_INCREMENT PRIMARY KEY,
    semester_start DATE NOT NULL,
    semester_end DATE NOT NULL,
    CONSTRAINT chk_semester_dates CHECK (semester_start < semester_end)
);

CREATE TABLE Faculty (
    faculty_id INT AUTO_INCREMENT PRIMARY KEY,
    faculty_name VARCHAR(100) NOT NULL
);

CREATE TABLE Subject (
    subject_id INT AUTO_INCREMENT PRIMARY KEY,
    subject_name VARCHAR(100) NOT NULL,
    faculty_id INT NOT NULL, -- Nét đôi: Tham gia toàn phần
    FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id)
);

-- 2. QUẢN LÝ NGƯỜI DÙNG VÀ TÀI KHOẢN (KẾ THỪA DISJOINT)
CREATE TABLE User (
    id INT AUTO_INCREMENT PRIMARY KEY,
    firstName VARCHAR(50) NOT NULL,
    middleName VARCHAR(50),
    lastName VARCHAR(50) NOT NULL,
    sex ENUM('Male', 'Female', 'Other'),
    email VARCHAR(100) UNIQUE NOT NULL,
    birthday DATE,
    nationality VARCHAR(50),
    CONSTRAINT chk_user_email CHECK (email LIKE '%@hcmut.edu.vn')
);

CREATE TABLE Student (
    id INT PRIMARY KEY,
    student_id VARCHAR(20) UNIQUE NOT NULL, 
    s_mssv VARCHAR(10) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE
);

CREATE TABLE Lecturer (
    id INT PRIMARY KEY,
    lecturer_id VARCHAR(20) UNIQUE NOT NULL,
    l_msgv VARCHAR(10) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE
);

CREATE TABLE Admin (
    id INT PRIMARY KEY,
    admin_id VARCHAR(20) UNIQUE NOT NULL,
    a_msqt VARCHAR(10) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE
);

CREATE TABLE User_acc (
    ua_id INT PRIMARY KEY,
    ua_username VARCHAR(50) UNIQUE NOT NULL, -- Khóa ứng viên (Gạch chân)
    ua_password VARCHAR(255) NOT NULL,
    ua_image VARCHAR(255),
    role_id INT NOT NULL,
    FOREIGN KEY (ua_id) REFERENCES User(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES Role(role_id)
);

-- 3. QUẢN LÝ LỚP HỌC
CREATE TABLE Class (
    class_id INT AUTO_INCREMENT PRIMARY KEY,
    class_name VARCHAR(100) NOT NULL,
    subject_id INT NOT NULL,   -- Nét đôi
    semester_id INT NOT NULL,  -- Nét đôi
    status_id INT NOT NULL,    -- Nét đôi
    lecturer_id INT,           -- Nét đơn (có thể NULL)
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id),
    FOREIGN KEY (semester_id) REFERENCES Semester(semester_id),
    FOREIGN KEY (status_id) REFERENCES Status(status_id),
    FOREIGN KEY (lecturer_id) REFERENCES Lecturer(id)
);

CREATE TABLE Enrollment (
    student_id INT,
    class_id INT,
    PRIMARY KEY (student_id, class_id),
    FOREIGN KEY (student_id) REFERENCES Student(id) ON DELETE CASCADE,
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE
);

-- 4. NỘI DUNG HỌC TẬP (CÁC THỰC THỂ YẾU)
CREATE TABLE Chapter (
    class_id INT,
    chapter_id INT, -- Khóa bộ phận
    chapter_name VARCHAR(255) NOT NULL,
    PRIMARY KEY (class_id, chapter_id),
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE
);

CREATE TABLE Topic (
    class_id INT,
    chapter_id INT,
    topic_id INT, -- Khóa bộ phận
    topic_name VARCHAR(255) NOT NULL,
    topic_content TEXT,
    PRIMARY KEY (class_id, chapter_id, topic_id),
    FOREIGN KEY (class_id, chapter_id) REFERENCES Chapter(class_id, chapter_id) ON DELETE CASCADE
);

CREATE TABLE File (
    class_id INT,
    chapter_id INT,
    topic_id INT,
    file_id INT, -- Khóa bộ phận
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(512) NOT NULL,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (class_id, chapter_id, topic_id, file_id),
    FOREIGN KEY (class_id, chapter_id, topic_id) REFERENCES Topic(class_id, chapter_id, topic_id) ON DELETE CASCADE
);

-- 5. BÀI KIỂM TRA (TEST & SUBCLASSES)
CREATE TABLE Test (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(255) NOT NULL,
    test_start DATETIME,
    test_end DATETIME,
    test_timer INT, 
    class_id INT NOT NULL,
    chapter_id INT,
    FOREIGN KEY (class_id) REFERENCES Class(class_id),
    FOREIGN KEY (class_id, chapter_id) REFERENCES Chapter(class_id, chapter_id)
);

CREATE TABLE Quiz (
    test_id INT PRIMARY KEY,
    quizz_id VARCHAR(50) UNIQUE NOT NULL,
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);

CREATE TABLE File_submission (
    test_id INT PRIMARY KEY,
    fs_id VARCHAR(50) UNIQUE NOT NULL,
    path VARCHAR(512),
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);

-- 6. NGÂN HÀNG CÂU HỎI
CREATE TABLE Question (
    question_id INT AUTO_INCREMENT PRIMARY KEY,
    question_type VARCHAR(50),
    question_content TEXT NOT NULL,
    test_id INT NOT NULL,
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);

CREATE TABLE Choice (
    choice_id INT AUTO_INCREMENT PRIMARY KEY,
    choice_content TEXT NOT NULL,
    is_true BOOLEAN DEFAULT FALSE,
    question_id INT NOT NULL,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE
);

-- 7. QUÁ TRÌNH LÀM BÀI CỦA SINH VIÊN (THỰC THỂ MẠNH TỪ SƠ ĐỒ)
CREATE TABLE Attempt (
    attempt_id INT AUTO_INCREMENT PRIMARY KEY,
    attempt_index INT,
    end_time DATETIME,
    score DECIMAL(5,2) CHECK (score >= 0),
    timer INT,
    test_id INT NOT NULL,
    student_id INT NOT NULL, -- Nối chuẩn với Student từ hình thoi "thực hiện"
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES Student(id) ON DELETE CASCADE
);

CREATE TABLE Student_answer (
    ans_id INT AUTO_INCREMENT PRIMARY KEY,
    attempt_id INT NOT NULL,
    question_id INT NOT NULL,
    choice_id INT,
    FOREIGN KEY (attempt_id) REFERENCES Attempt(attempt_id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE,
    FOREIGN KEY (choice_id) REFERENCES Choice(choice_id) ON DELETE CASCADE
);

-- 8. TƯƠNG TÁC LỚP HỌC (POST & COMMENT - THỰC THỂ MẠNH)
CREATE TABLE Post (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    post_name VARCHAR(255) NOT NULL,
    post_description TEXT,
    post_start DATETIME,
    post_end DATETIME,
    ua_id INT NOT NULL, 
    class_id INT NOT NULL,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id),
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE
);

CREATE TABLE Comment (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    comment_content TEXT NOT NULL,
    comment_start DATETIME DEFAULT CURRENT_TIMESTAMP,
    post_id INT NOT NULL,
    ua_id INT NOT NULL,
    FOREIGN KEY (post_id) REFERENCES Post(post_id) ON DELETE CASCADE,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id)
);