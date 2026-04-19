-- ============================================================
-- DATABASE CORE – CHUẨN HÓA THEO ERD
-- 1. Tạo bảng & ràng buộc (Bám sát thuộc tính từ ERD)
-- 2. Dữ liệu mẫu (≥5 dòng/bảng)
-- 3. Trigger nghiệp vụ (Ràng buộc thời gian & Tính điểm tự động)
-- ============================================================

DROP DATABASE IF EXISTS ELearningDB;
CREATE DATABASE ELearningDB;
USE ELearningDB;

-- ------------------------------------------------------------
-- 1. TẠO BẢNG VÀ RÀNG BUỘC
-- ------------------------------------------------------------

-- [DANH MỤC CƠ BẢN]
CREATE TABLE Role (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Status (
    status_id INT AUTO_INCREMENT PRIMARY KEY,
    status_display VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Semester (
    semester_id INT AUTO_INCREMENT PRIMARY KEY,
    semester_start DATE NOT NULL,
    semester_end DATE NOT NULL,
    CONSTRAINT chk_semester_dates CHECK (semester_start < semester_end)
);

CREATE TABLE Faculty (
    faculty_id INT AUTO_INCREMENT PRIMARY KEY,
    faculty_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE Subject (
    subject_id INT AUTO_INCREMENT PRIMARY KEY,
    subject_name VARCHAR(100) NOT NULL,
    faculty_id INT NOT NULL,
    FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- [NGƯỜI DÙNG VÀ PHÂN QUYỀN - KẾ THỪA]
CREATE TABLE User (
    id INT AUTO_INCREMENT PRIMARY KEY,
    firstName VARCHAR(50) NOT NULL,
    middleName VARCHAR(50),
    lastName VARCHAR(50) NOT NULL,
    sex ENUM('Male', 'Female', 'Other') NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    birthday DATE,
    nationality VARCHAR(50)
);

CREATE TABLE Student (
    id INT PRIMARY KEY,
    s_mssv VARCHAR(20) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Lecturer (
    id INT PRIMARY KEY,
    l_msgv VARCHAR(20) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Admin (
    id INT PRIMARY KEY,
    a_msqt VARCHAR(20) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE User_acc (
    ua_id INT PRIMARY KEY,
    ua_username VARCHAR(50) UNIQUE NOT NULL,
    ua_password VARCHAR(255) NOT NULL,
    ua_image VARCHAR(255),
    role_id INT NOT NULL,
    FOREIGN KEY (ua_id) REFERENCES User(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (role_id) REFERENCES Role(role_id) ON UPDATE CASCADE
);

-- [LỚP HỌC VÀ GHI DANH]
CREATE TABLE Class (
    class_id INT AUTO_INCREMENT PRIMARY KEY,
    class_name VARCHAR(100) NOT NULL,
    subject_id INT NOT NULL,
    semester_id INT NOT NULL,
    status_id INT NOT NULL,
    lecturer_id INT,
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id) ON UPDATE CASCADE,
    FOREIGN KEY (semester_id) REFERENCES Semester(semester_id) ON UPDATE CASCADE,
    FOREIGN KEY (status_id) REFERENCES Status(status_id) ON UPDATE CASCADE,
    FOREIGN KEY (lecturer_id) REFERENCES Lecturer(id) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE Enrollment (
    student_id INT,
    class_id INT,
    PRIMARY KEY (student_id, class_id),
    FOREIGN KEY (student_id) REFERENCES Student(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- [NỘI DUNG HỌC TẬP - ENTITY YẾU (WEAK ENTITIES)]
CREATE TABLE Chapter (
    class_id INT,
    chapter_id INT,
    chapter_name VARCHAR(255) NOT NULL,
    PRIMARY KEY (class_id, chapter_id),
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Topic (
    class_id INT,
    chapter_id INT,
    topic_id INT,
    topic_name VARCHAR(255) NOT NULL,
    topic_content TEXT,
    PRIMARY KEY (class_id, chapter_id, topic_id),
    FOREIGN KEY (class_id, chapter_id) REFERENCES Chapter(class_id, chapter_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE File (
    class_id INT,
    chapter_id INT,
    topic_id INT,
    file_id INT,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(512) NOT NULL,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (class_id, chapter_id, topic_id, file_id),
    FOREIGN KEY (class_id, chapter_id, topic_id) REFERENCES Topic(class_id, chapter_id, topic_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- [KIỂM TRA VÀ ĐÁNH GIÁ - KẾ THỪA]
CREATE TABLE Test (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(255) NOT NULL,
    test_start DATETIME,
    test_end DATETIME,
    test_timer INT COMMENT 'Đơn vị tính bằng phút',
    class_id INT NOT NULL,
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_test_dates CHECK (test_start < test_end)
);

CREATE TABLE Quiz (
    test_id INT PRIMARY KEY,
    quizz_id VARCHAR(50) UNIQUE NOT NULL,
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE File_submission (
    test_id INT PRIMARY KEY,
    fs_id VARCHAR(50) UNIQUE NOT NULL,
    path VARCHAR(512),
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- [CÂU HỎI VÀ ĐÁP ÁN]
CREATE TABLE Question (
    question_id INT AUTO_INCREMENT PRIMARY KEY,
    question_type ENUM('multiple_choice', 'true_false', 'essay') NOT NULL,
    question_content TEXT NOT NULL,
    score DECIMAL(5,2) DEFAULT 1.00, -- Bổ sung từ ERD
    test_id INT NOT NULL,
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Choice (
    choice_id INT AUTO_INCREMENT PRIMARY KEY,
    choice_content TEXT NOT NULL,
    is_true BOOLEAN DEFAULT FALSE,
    question_id INT NOT NULL,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- [LÀM BÀI VÀ GHI NHẬN KẾT QUẢ]
CREATE TABLE Attempt (
    attempt_id INT AUTO_INCREMENT PRIMARY KEY,
    attempt_index INT NOT NULL,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    timer INT,
    test_id INT NOT NULL,
    student_id INT NOT NULL,
    total_score DECIMAL(5,2) DEFAULT 0.00, -- Derived Attribute được cập nhật tự động bằng Trigger
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (student_id) REFERENCES Student(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Student_answer (
    ans_id INT AUTO_INCREMENT PRIMARY KEY,
    attempt_id INT NOT NULL,
    question_id INT NOT NULL,
    choice_id INT NULL,
    answer_text TEXT NULL,
    FOREIGN KEY (attempt_id) REFERENCES Attempt(attempt_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (choice_id) REFERENCES Choice(choice_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_answer_type CHECK (
        (choice_id IS NOT NULL AND answer_text IS NULL) OR
        (choice_id IS NULL AND answer_text IS NOT NULL)
    )
);

-- [TƯƠNG TÁC LỚP HỌC]
CREATE TABLE Post (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    post_name VARCHAR(255) NOT NULL,
    post_description TEXT,
    post_start DATETIME,
    post_end DATETIME,
    ua_id INT NOT NULL,
    class_id INT NOT NULL,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Comment (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    comment_content TEXT NOT NULL,
    comment_start DATETIME DEFAULT CURRENT_TIMESTAMP,
    post_id INT NOT NULL,
    ua_id INT NOT NULL,
    FOREIGN KEY (post_id) REFERENCES Post(post_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ------------------------------------------------------------
-- 2. DỮ LIỆU MẪU ĐỂ CHẠY THỬ
-- ------------------------------------------------------------

INSERT INTO Role (role_name) VALUES ('Student'), ('Lecturer'), ('Admin'), ('TA'), ('Guest');
INSERT INTO Status (status_display) VALUES ('Open'), ('Closed'), ('Ongoing'), ('Cancelled'), ('Completed');
INSERT INTO Semester (semester_start, semester_end) VALUES
('2025-01-01', '2025-05-31'), ('2025-06-01', '2025-08-31'), ('2025-09-01', '2025-12-31'),
('2026-01-01', '2026-05-31'), ('2026-06-01', '2026-08-31');

INSERT INTO Faculty (faculty_name) VALUES ('Computer Science'), ('Electrical Engineering'), ('Mechanical Engineering'), ('Civil Engineering'), ('Business');
INSERT INTO Subject (subject_name, faculty_id) VALUES ('Database Systems', 1), ('Data Structures', 1), ('Circuit Analysis', 2), ('Thermodynamics', 3), ('Macroeconomics', 5);

INSERT INTO User (firstName, lastName, sex, email) VALUES
('Nguyen', 'An', 'Male', 'an@abc.com'), ('Tran', 'Binh', 'Female', 'binh@abc.com'), ('Le', 'Chau', 'Male', 'chau@abc.com'),
('Vo', 'Hai', 'Male', 'hai@abc.com'), ('Ngo', 'Nga', 'Female', 'nga@abc.com');

INSERT INTO Student (id, s_mssv) VALUES (1, 'SV001'), (2, 'SV002'), (3, 'SV003');
INSERT INTO Lecturer (id, l_msgv) VALUES (4, 'GV001');
INSERT INTO Admin (id, a_msqt) VALUES (5, 'AD001');

INSERT INTO User_acc (ua_id, ua_username, ua_password, role_id) VALUES
(1, 'student1', '123', 1), (2, 'student2', '123', 1), (3, 'student3', '123', 1),
(4, 'lecturer1', '123', 2), (5, 'admin1', '123', 3);

INSERT INTO Class (class_name, subject_id, semester_id, status_id, lecturer_id) VALUES
('DB_01', 1, 1, 1, 4), ('DS_02', 2, 1, 1, 4), ('Circuit_01', 3, 1, 1, NULL),
('Thermo_01', 4, 1, 2, 4), ('Macro_01', 5, 2, 1, 4);

INSERT INTO Enrollment (student_id, class_id) VALUES (1,1), (2,1), (3,1), (1,2), (2,3);

INSERT INTO Chapter (class_id, chapter_id, chapter_name) VALUES (1,1,'Intro'), (1,2,'ERD'), (2,1,'Arrays'), (2,2,'Trees'), (3,1,'Ohm Law');
INSERT INTO Topic (class_id, chapter_id, topic_id, topic_name) VALUES (1,1,1,'DBMS'), (1,1,2,'Relational'), (1,2,1,'Keys'), (1,2,2,'Norm'), (2,1,1,'Static Arrays');
INSERT INTO File (class_id, chapter_id, topic_id, file_id, file_name, file_path) VALUES 
(1,1,1,1,'slide1.pdf','/url1'), (1,1,2,1,'slide2.pdf','/url2'), (1,2,1,1,'keys.mp4','/url3'), (1,2,2,1,'lab1.doc','/url4'), (2,1,1,1,'code.zip','/url5');

INSERT INTO Test (test_name, test_start, test_end, test_timer, class_id) VALUES
('Midterm DB', '2025-03-01 08:00:00', '2025-03-01 10:00:00', 90, 1),
('Quiz 1 DS', '2025-03-05 13:00:00', '2025-03-05 14:00:00', 30, 2),
('Final DB', '2025-05-20 07:00:00', '2025-05-20 09:30:00', 120, 1),
('Lab DS', '2025-03-10 00:00:00', '2025-03-12 23:59:59', 0, 2),
('Test Circ', '2025-04-01 08:00:00', '2025-04-01 09:00:00', 45, 3);

INSERT INTO Quiz (test_id, quizz_id) VALUES (1, 'QZ001'), (2, 'QZ002');
INSERT INTO File_submission (test_id, fs_id, path) VALUES (4, 'FS001', '/submit');

INSERT INTO Question (question_type, question_content, score, test_id) VALUES
('multiple_choice', 'Primary Key là gì?', 2.0, 1),
('true_false', 'Foreign Key có thể mang giá trị NULL', 1.0, 1),
('essay', 'Thiết kế ERD cho bài toán quản lý thư viện.', 7.0, 1),
('multiple_choice', 'Độ phức tạp O(n) là gì?', 2.0, 2),
('true_false', 'Array lưu trữ bộ nhớ liên tục', 1.0, 2);

INSERT INTO Choice (choice_content, is_true, question_id) VALUES
('Khoá chính', 1, 1), ('Khoá ngoại', 0, 1), ('Đúng', 1, 2), ('Sai', 0, 2),
('Tuyến tính', 1, 4), ('Logarit', 0, 4), ('True', 1, 5), ('False', 0, 5);

INSERT INTO Attempt (attempt_index, test_id, student_id) VALUES 
(1, 1, 1), (1, 1, 2), (2, 1, 1), (1, 2, 3), (1, 2, 1);

-- ------------------------------------------------------------
-- 3. TRIGGER NGHIỆP VỤ CAO CẤP
-- ------------------------------------------------------------
DELIMITER //

-- [TRIGGER 1]: Kiểm tra thời gian làm bài hợp lệ
CREATE TRIGGER trg_check_attempt_time
BEFORE INSERT ON Attempt
FOR EACH ROW
BEGIN
    DECLARE v_start DATETIME;
    DECLARE v_end DATETIME;
    
    SELECT test_start, test_end INTO v_start, v_end 
    FROM Test WHERE test_id = NEW.test_id;
    
    IF NEW.start_time < v_start OR NEW.start_time > v_end THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian bắt đầu làm bài không nằm trong khoảng thời gian cho phép của bài kiểm tra.';
    END IF;
END//

-- [TRIGGER 2]: Tự động cập nhật thuộc tính dẫn xuất total_score
-- Mô tả: Khi một câu trả lời mới được thêm vào, nếu đúng (dựa vào is_true trong Choice), 
-- tự động lấy điểm của Question cộng dồn vào Attempt.total_score
CREATE TRIGGER trg_auto_update_score
AFTER INSERT ON Student_answer
FOR EACH ROW
BEGIN
    DECLARE v_is_correct BOOLEAN DEFAULT 0;
    DECLARE v_score DECIMAL(5,2) DEFAULT 0.00;
    
    -- Nếu có câu trả lời trắc nghiệm
    IF NEW.choice_id IS NOT NULL THEN
        SELECT is_true INTO v_is_correct FROM Choice WHERE choice_id = NEW.choice_id;
        
        IF v_is_correct THEN
            SELECT score INTO v_score FROM Question WHERE question_id = NEW.question_id;
            
            UPDATE Attempt 
            SET total_score = total_score + v_score 
            WHERE attempt_id = NEW.attempt_id;
        END IF;
    END IF;
END//

DELIMITER ;