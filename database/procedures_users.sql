-- ==========================================
-- QUẢN LÝ NGƯỜI DÙNG 
-- ==========================================
DELIMITER //

DROP PROCEDURE IF EXISTS sp_CreateStudent//

CREATE PROCEDURE sp_CreateStudent(
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_email VARCHAR(100),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50),
    IN p_user_code VARCHAR(20), -- Mã sinh viên (dùng làm student_id, MSSV và username)
    OUT p_new_user_id INT       -- Trả về id User vừa được tạo
)
BEGIN
    DECLARE v_role_id INT;          -- Lưu role_id của Student
    DECLARE v_salt VARCHAR(64);     -- Salt dùng để hash password
    DECLARE v_error_msg VARCHAR(512); -- Lưu thông báo lỗi hệ thống

    -- Handler cho lỗi trùng UNIQUE (email, MSSV, username...)
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Email hoặc Mã số đã tồn tại!';
    END;

    -- Handler cho lỗi SQL tổng quát
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK; 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Validate domain email theo rule hệ thống
    IF TRIM(p_email) NOT LIKE '%@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Email phải có đuôi @hcmut.edu.vn!';
    END IF;

    START TRANSACTION;

    -- Lấy role_id của Student (hard-code để tránh privilege escalation)
    SELECT role_id INTO v_role_id 
    FROM Role 
    WHERE role_name = 'Student' 
    LIMIT 1;
    
    -- 1. Tạo User (bảng cha)
    INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality)
    VALUES (
        TRIM(p_firstName), 
        TRIM(p_middleName), 
        TRIM(p_lastName), 
        p_sex, 
        TRIM(p_email), 
        p_birthday, 
        TRIM(p_nationality)
    );

    -- Lấy id vừa tạo
    SET p_new_user_id = LAST_INSERT_ID();

    -- 2. Tạo Student (subclass của User)
    INSERT INTO Student (id, student_id, s_mssv)
    VALUES (
        p_new_user_id, 
        TRIM(p_user_code), 
        TRIM(p_user_code)
    );

    -- 3. Tạo tài khoản đăng nhập (User_acc)
    -- Password = SHA2(email + salt)
    SET v_salt = UUID();

    INSERT INTO User_acc (ua_id, ua_username, ua_password, salt, role_id, is_active)
    VALUES (
        p_new_user_id, 
        TRIM(p_user_code), 
        SHA2(CONCAT(TRIM(p_email), v_salt), 256), 
        v_salt, 
        v_role_id, 
        TRUE
    );

    COMMIT;
END //
DELIMITER ;

-- ==========================================
-- TẠO GIẢNG VIÊN (Create Lecturer)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateLecturer//

CREATE PROCEDURE sp_CreateLecturer(
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_email VARCHAR(100),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50),
    IN p_lecturer_id VARCHAR(20), -- Mã định danh nghiệp vụ của giảng viên
    IN p_l_msgv VARCHAR(10),      -- Mã số giảng viên (dùng làm username)
    OUT p_new_user_id INT         -- Trả về id User vừa được tạo
)
BEGIN
    DECLARE v_role_id INT;          
    DECLARE v_salt VARCHAR(64);     
    DECLARE v_error_msg VARCHAR(512);

    -- Handler cho lỗi trùng dữ liệu UNIQUE
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Email, MSGV hoặc ID giảng viên đã tồn tại!';
    END;

    -- Handler cho lỗi SQL tổng quát
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Validate email theo rule hệ thống
    IF TRIM(p_email) NOT LIKE '%@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Email giảng viên phải có đuôi @hcmut.edu.vn!';
    END IF;

    START TRANSACTION;

    -- Lấy role_id của Lecturer
    SELECT role_id INTO v_role_id 
    FROM Role 
    WHERE role_name = 'Lecturer' 
    LIMIT 1;

    -- Kiểm tra role đã được cấu hình chưa
    IF v_role_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Hệ thống chưa cấu hình Role Lecturer!';
    END IF;

    -- 1. Tạo User
    INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality)
    VALUES (
        TRIM(p_firstName), 
        TRIM(p_middleName), 
        TRIM(p_lastName), 
        p_sex, 
        TRIM(p_email), 
        p_birthday, 
        TRIM(p_nationality)
    );

    SET p_new_user_id = LAST_INSERT_ID();

    -- 2. Tạo Lecturer
    INSERT INTO Lecturer (id, lecturer_id, l_msgv)
    VALUES (
        p_new_user_id, 
        TRIM(p_lecturer_id), 
        TRIM(p_l_msgv)
    );

    -- 3. Tạo tài khoản đăng nhập
    SET v_salt = UUID();

    INSERT INTO User_acc (ua_id, ua_username, ua_password, salt, role_id, is_active)
    VALUES (
        p_new_user_id, 
        TRIM(p_l_msgv), 
        SHA2(CONCAT(TRIM(p_email), v_salt), 256), 
        v_salt, 
        v_role_id, 
        TRUE
    );

    COMMIT;
END //

-- ==========================================
-- CẬP NHẬT THÔNG TIN NGƯỜI DÙNG (Update Profile)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_UpdateUserInfo//

CREATE PROCEDURE sp_UpdateUserInfo(
    IN p_user_id INT,
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50)
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- Handler cho lỗi SQL tổng quát
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Chuẩn hóa input
    SET p_firstName = TRIM(p_firstName);
    SET p_lastName = TRIM(p_lastName);

    -- Validate dữ liệu đầu vào
    IF p_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: User ID không được để trống!';
    END IF;

    IF p_firstName = '' OR p_lastName = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Họ và Tên không được để trống!';
    END IF;

    IF p_sex IS NOT NULL AND p_sex NOT IN ('Male', 'Female', 'Other') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Giới tính không hợp lệ!';
    END IF;

    -- Kiểm tra tồn tại user
    IF NOT EXISTS (SELECT 1 FROM User WHERE id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Người dùng không tồn tại trong hệ thống!';
    END IF;

    START TRANSACTION;
    
    -- Cập nhật thông tin User
    UPDATE User 
    SET 
        firstName = p_firstName,
        middleName = p_middleName,
        lastName = p_lastName,
        sex = p_sex,
        birthday = p_birthday,
        nationality = p_nationality
    WHERE id = p_user_id;

    COMMIT;
END //

-- ==========================================
-- ĐỔI MẬT KHẨU (Change Password)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_ChangePassword//

CREATE PROCEDURE sp_ChangePassword(
    IN p_user_id INT,
    IN p_old_password VARCHAR(255),
    IN p_new_password VARCHAR(255)
)
BEGIN
    DECLARE v_email VARCHAR(100);
    DECLARE v_current_hash VARCHAR(255);
    DECLARE v_current_salt VARCHAR(64);
    DECLARE v_new_salt VARCHAR(64);
    DECLARE v_error_msg VARCHAR(512);

    -- Handler cho lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Validate input
    IF p_user_id IS NULL OR p_old_password = '' OR p_new_password = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Các trường mật khẩu không được để trống!';
    END IF;

    IF CHAR_LENGTH(p_new_password) < 6 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Mật khẩu mới phải có ít nhất 6 ký tự!';
    END IF;

    -- Lấy thông tin hiện tại (email + hash + salt)
    SELECT u.email, ua.ua_password, ua.salt 
    INTO v_email, v_current_hash, v_current_salt
    FROM User_acc ua
    JOIN User u ON ua.ua_id = u.id
    WHERE ua.ua_id = p_user_id;

    IF v_current_hash IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tài khoản không tồn tại!';
    END IF;

    -- Xác thực mật khẩu cũ
    IF v_current_hash != SHA2(CONCAT(TRIM(v_email), v_current_salt), 256) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Mật khẩu cũ không chính xác!';
    END IF;

    START TRANSACTION;
    
    -- Tạo salt mới và cập nhật password
    SET v_new_salt = UUID();
    
    UPDATE User_acc 
    SET 
        ua_password = SHA2(CONCAT(TRIM(v_email), v_new_salt), 256),
        salt = v_new_salt
    WHERE ua_id = p_user_id;

    COMMIT;
END //

-- ==========================================
-- KHÓA / MỞ KHÓA TÀI KHOẢN (Soft Delete)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_ToggleUserStatus//

CREATE PROCEDURE sp_ToggleUserStatus(
    IN p_user_id INT,
    IN p_is_active BOOLEAN
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Kiểm tra tồn tại tài khoản
    IF NOT EXISTS (SELECT 1 FROM User_acc WHERE ua_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tài khoản không tồn tại trong hệ thống!';
    END IF;

    START TRANSACTION;
    
    -- Soft delete: bật/tắt trạng thái hoạt động
    UPDATE User_acc 
    SET is_active = p_is_active 
    WHERE ua_id = p_user_id;

    COMMIT;
END //

-- ==========================================
-- XÓA NGƯỜI DÙNG VĨNH VIỄN (Hard Delete)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_DeleteUser//

CREATE PROCEDURE sp_DeleteUser(
    IN p_user_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Kiểm tra tồn tại user
    IF NOT EXISTS (SELECT 1 FROM User WHERE id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Người dùng không tồn tại!';
    END IF;

    START TRANSACTION;
    
    -- Xóa vật lý User (cascade sẽ tự động xóa các bảng con)
    DELETE FROM User WHERE id = p_user_id;

    COMMIT;
END //

DELIMITER ;