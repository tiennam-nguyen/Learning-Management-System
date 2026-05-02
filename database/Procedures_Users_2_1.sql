USE elearning;
DELIMITER //

-- ==========================================================
-- PHẦN 1: CÁC STORED PROCEDURE THỰC HIỆN INSERT DỮ LIỆU
-- Mỗi procedure xử lý riêng cho từng bảng (đảm bảo tính module)
-- ==========================================================

-- ----------------------------------------------------------
-- 1.1 Procedure: sp_InsertUser
-- Chức năng: Thêm mới một bản ghi vào bảng User
-- Bao gồm kiểm tra dữ liệu đầu vào và ràng buộc nghiệp vụ
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_InsertUser//

CREATE PROCEDURE sp_InsertUser(
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_email VARCHAR(100),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50),
    OUT p_new_user_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);
    
    -- Handler: Xử lý lỗi trùng khóa (email unique)
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Email đã tồn tại trong hệ thống!';
    END;
    
    -- Handler: Xử lý lỗi SQL tổng quát
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- [Validation 1] Kiểm tra dữ liệu bắt buộc (NOT NULL & NOT EMPTY)
    IF p_firstName IS NULL OR TRIM(p_firstName) = '' OR 
        p_lastName IS NULL OR TRIM(p_lastName) = '' OR 
        p_sex IS NULL OR TRIM(p_sex) = '' OR 
        p_email IS NULL OR TRIM(p_email) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Các thông tin bắt buộc không được để trống hoặc NULL!';
    END IF;

    -- [Validation 2] Kiểm tra miền giá trị của giới tính (ENUM logic)
    IF p_sex NOT IN ('Male', 'Female', 'Other') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Giới tính không hợp lệ!';
    END IF;

    -- [Validation 3] Kiểm tra định dạng email theo domain tổ chức
    IF RIGHT(TRIM(p_email), 13) != '@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Email k hợp lệ!';
    END IF;

    -- [Validation 4] Kiểm tra độ tuổi (>= 18)
    IF p_birthday IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Ngày sinh là bắt buộc!';
    END IF;

    IF TIMESTAMPDIFF(YEAR, p_birthday, CURDATE()) < 18 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Người dùng phải đủ 18 tuổi!';
    END IF;

    -- Thực thi transaction
    START TRANSACTION;

    INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality)
    VALUES (TRIM(p_firstName), TRIM(p_middleName), TRIM(p_lastName), 
            p_sex, TRIM(p_email), p_birthday, TRIM(p_nationality));
    
    -- Lấy ID vừa insert
    SET p_new_user_id = LAST_INSERT_ID();

    COMMIT;
END//

-- ----------------------------------------------------------
-- 1.2 Procedure: sp_InsertStudent
-- Chức năng: Thêm một sinh viên dựa trên user_id đã tồn tại
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_InsertStudent//
CREATE PROCEDURE sp_InsertStudent(
    IN p_user_id INT,
    IN p_mssv VARCHAR(20)
)
BEGIN
    -- Kiểm tra dữ liệu đầu vào
    IF p_user_id IS NULL OR p_mssv IS NULL OR TRIM(p_mssv) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ID và MSSV không được để trống!';
    END IF;

    START TRANSACTION;
    INSERT INTO Student (id, s_mssv) VALUES (p_user_id, TRIM(p_mssv));
    COMMIT;
END//

-- ----------------------------------------------------------
-- 1.3 Procedure: sp_InsertLecturer
-- Chức năng: Thêm giảng viên
-- Kiểm tra thêm về trình độ (degree)
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_InsertLecturer//
-- ----------------------------------------------------------
-- 1.3 Procedure: sp_InsertLecturer
-- Chức năng: Thêm giảng viên
-- Cập nhật: Tách dữ liệu Insert vào 2 bảng Lecturer và Lecturer_Degree
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_InsertLecturer;
CREATE PROCEDURE sp_InsertLecturer(
    IN p_user_id INT,
    IN p_msgv VARCHAR(20),
    IN p_degree VARCHAR(20)
)
BEGIN
    -- [1] Kiểm tra dữ liệu bắt buộc
    IF p_user_id IS NULL OR p_msgv IS NULL OR TRIM(p_msgv) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ID và MSGV không hợp lệ!';
    END IF;

    -- [2] Kiểm tra ENUM degree
    IF p_degree IS NULL OR p_degree NOT IN ('Bachelor', 'Master', 'PhD') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Trình độ (Degree) phải thuộc {Bachelor, Master, PhD}!';
    END IF;

    -- [3] Thực thi Transaction (Ghi vào 2 bảng)
    START TRANSACTION;
    
    -- Insert vào bảng Lecturer trước (bỏ cột degree đi)
    INSERT INTO Lecturer (id, l_msgv) 
    VALUES (p_user_id, TRIM(p_msgv));
    
    -- Bổ sung Insert vào bảng Lecturer_Degree (bảng con)
    INSERT INTO Lecturer_Degree (lecturer_id, degree) 
    VALUES (p_user_id, p_degree);
    
    COMMIT;
END//

-- ----------------------------------------------------------
-- 1.4 Procedure: sp_InsertAdmin
-- Chức năng: Thêm quản trị viên
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_InsertAdmin//
CREATE PROCEDURE sp_InsertAdmin(
    IN p_user_id INT,
    IN p_msqt VARCHAR(20),
    IN p_degree VARCHAR(20)
)
BEGIN
    -- Kiểm tra dữ liệu đầu vào
    IF p_user_id IS NULL OR p_msqt IS NULL OR TRIM(p_msqt) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ID và MSQT không hợp lệ!';
    END IF;

    -- Kiểm tra degree
    IF p_degree IS NULL OR p_degree NOT IN ('Bachelor', 'Master', 'PhD') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Degree không hợp lệ!';
    END IF;

    START TRANSACTION;
    INSERT INTO Admin (id, a_msqt, degree) 
    VALUES (p_user_id, TRIM(p_msqt), p_degree);
    COMMIT;
END//

-- ----------------------------------------------------------
-- 1.5 Procedure: sp_InsertUserAccount
-- Chức năng: Tạo tài khoản đăng nhập cho User
-- Password được hash bằng SHA2
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_InsertUserAccount//
CREATE PROCEDURE sp_InsertUserAccount(
    IN p_user_id INT,
    IN p_username VARCHAR(50),
    IN p_raw_password VARCHAR(255)
)
BEGIN
    -- Kiểm tra dữ liệu đầu vào
    IF p_user_id IS NULL OR p_username IS NULL OR TRIM(p_username) = '' 
    OR p_raw_password IS NULL OR TRIM(p_raw_password) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Thiếu thông tin tài khoản!';
    END IF;

    START TRANSACTION;
    INSERT INTO User_acc (ua_id, ua_username, ua_password)
    VALUES (p_user_id, TRIM(p_username), SHA2(TRIM(p_raw_password), 256));
    COMMIT;
END//

-- ==========================================================
-- PHẦN 2: PROCEDURE UPDATE
-- ==========================================================

-- ----------------------------------------------------------
-- Procedure: sp_UpdateUser
-- Chức năng: Cập nhật thông tin User
-- Bao gồm kiểm tra tồn tại + validation đầy đủ
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_UpdateUser//
CREATE PROCEDURE sp_UpdateUser(
    IN p_user_id INT,
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_email VARCHAR(100),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50)
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);
    DECLARE v_exists INT DEFAULT 0;

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- [Check 1] Kiểm tra ID hợp lệ và tồn tại
    IF p_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ID không hợp lệ!';
    END IF;

    SELECT COUNT(*) INTO v_exists FROM User WHERE id = p_user_id;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'User không tồn tại!';
    END IF;

    -- [Check 2] Validation dữ liệu tương tự 
    IF p_firstName IS NULL OR TRIM(p_firstName) = '' OR 
        p_lastName IS NULL OR TRIM(p_lastName) = '' OR 
        p_sex IS NULL OR TRIM(p_sex) = '' OR 
        p_email IS NULL OR TRIM(p_email) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Thiếu dữ liệu bắt buộc!';
    END IF;

    IF p_sex NOT IN ('Male', 'Female', 'Other') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Giới tính không hợp lệ!';
    END IF;

    IF RIGHT(TRIM(p_email), 13) != '@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Email k hợp lệ';
    END IF;

    IF p_birthday IS NULL OR TIMESTAMPDIFF(YEAR, p_birthday, CURDATE()) < 18 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Tuổi không hợp lệ!';
    END IF;

    -- [Check 3] Ràng buộc unique email
    IF EXISTS (SELECT 1 FROM User WHERE email = TRIM(p_email) AND id != p_user_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Email đã được sử dụng!';
    END IF;

    START TRANSACTION;

    UPDATE User 
    SET firstName = TRIM(p_firstName),
        middleName = TRIM(p_middleName),
        lastName = TRIM(p_lastName),
        sex = p_sex,
        email = TRIM(p_email),
        birthday = p_birthday,
        nationality = TRIM(p_nationality)
    WHERE id = p_user_id;

    COMMIT;
END //

-- ==========================================================
-- PHẦN 3: PROCEDURE DELETE
-- ==========================================================

-- ----------------------------------------------------------
-- Procedure: sp_DeleteUser
-- Chức năng: Xóa User
-- Có kiểm tra ràng buộc dữ liệu học thuật 
-- ----------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DeleteUser//
CREATE PROCEDURE sp_DeleteUser(
    IN p_user_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_is_teaching INT DEFAULT 0;
    DECLARE v_has_attempt INT DEFAULT 0;

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- [Check 1] ID hợp lệ
    IF p_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ID không hợp lệ!';
    END IF;

    -- [Check 2] User tồn tại
    SELECT COUNT(*) INTO v_exists FROM User WHERE id = p_user_id;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'User không tồn tại!';
    END IF;

    -- [Check 3] Ràng buộc giảng viên (đã dạy lớp)
    SELECT COUNT(*) INTO v_is_teaching FROM Class WHERE lecturer_id = p_user_id;
    IF v_is_teaching > 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Không thể xóa giảng viên đã/đang dạy!';
    END IF;

    -- [Check 4] Ràng buộc sinh viên (đã làm bài)
    SELECT COUNT(*) INTO v_has_attempt FROM Attempt WHERE student_id = p_user_id;
    IF v_has_attempt > 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Không thể xóa sinh viên đã có Attempt!';
    END IF;

    START TRANSACTION;
    DELETE FROM User WHERE id = p_user_id;
    COMMIT;
END //

DELIMITER ;
