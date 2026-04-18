-- ==========================================
-- SCRIPT QUẢN LÝ NGƯỜI DÙNG 
-- ==========================================

-- 2. ĐỔI DELIMITER ĐỂ BẮT ĐẦU TẠO CÁC PROCEDURES
DELIMITER //

-- ==========================================
-- 3. TẠO SINH VIÊN (Create Student)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateStudent//

CREATE PROCEDURE sp_CreateStudent(
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_email VARCHAR(100),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50),
    IN p_student_id VARCHAR(20),
    IN p_s_mssv VARCHAR(10),
    IN p_role_id INT
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLERS)
    -- ==========================================
    
    -- Bắt lỗi vi phạm ràng buộc Toàn vẹn (Duplicate Entry - Mã 1062)
    -- Ngăn chặn trùng lặp các định danh duy nhất (Email, MSSV)
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email, MSSV hoặc User ID đã tồn tại trong hệ thống!';
    END;

    -- Bắt các ngoại lệ SQL chung và cắt chuỗi an toàn để tránh lỗi 'Data too long'
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. CHUẨN HÓA VÀ KIỂM TRA DỮ LIỆU (VALIDATION)
    -- ==========================================
    
    -- Bước 2.1: Chuẩn hóa dữ liệu đầu vào (Input Sanitization)
    SET p_firstName = TRIM(p_firstName);
    SET p_lastName = TRIM(p_lastName);
    SET p_email = TRIM(p_email);
    SET p_student_id = TRIM(p_student_id);
    SET p_s_mssv = TRIM(p_s_mssv);

    -- Bước 2.2: Ràng buộc Not Null (Data Constraint)
    IF p_firstName = '' OR p_lastName = '' OR p_email = '' OR p_student_id = '' OR p_s_mssv = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Vui lòng điền đủ các trường bắt buộc!';
    END IF;

    -- Bước 2.3: Ràng buộc Nghiệp vụ (Business Rule) - Email nội bộ
    IF p_email NOT LIKE '%@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email phải có đuôi @hcmut.edu.vn!';
    END IF;

    -- Bước 2.4: Ràng buộc Miền giá trị (Domain Constraint) - Khớp tập ENUM
    IF p_sex IS NOT NULL AND p_sex NOT IN ('Male', 'Female', 'Other') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Giới tính không hợp lệ (Male, Female, Other)!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;

    -- Ghi nhận dữ liệu Thực thể Cha (User)
    INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality)
    VALUES (p_firstName, p_middleName, p_lastName, p_sex, p_email, p_birthday, p_nationality);

    -- Lấy Khóa chính (Primary Key) vừa tạo để làm Khóa ngoại (Foreign Key)
    SET v_user_id = LAST_INSERT_ID();

    -- Ghi nhận dữ liệu Thực thể Con (Student)
    INSERT INTO Student (id, student_id, s_mssv)
    VALUES (v_user_id, p_student_id, p_s_mssv);

    -- Cấp phát tài khoản xác thực (Authentication Record) sử dụng thuật toán băm SHA256 + Salt
    INSERT INTO User_acc (ua_id, ua_username, ua_password, role_id)
    VALUES (v_user_id, p_s_mssv, SHA2(CONCAT(p_email, 'salt_bk'), 256), p_role_id);

    COMMIT;
END //

-- ==========================================
-- 4. TẠO GIẢNG VIÊN (Create Lecturer)
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
    IN p_lecturer_id VARCHAR(20),
    IN p_l_msgv VARCHAR(10),
    IN p_role_id INT
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLERS)
    -- ==========================================
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email, MSCB hoặc User ID đã tồn tại trong hệ thống!';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. CHUẨN HÓA VÀ KIỂM TRA DỮ LIỆU (VALIDATION)
    -- ==========================================
    SET p_firstName = TRIM(p_firstName);
    SET p_lastName = TRIM(p_lastName);
    SET p_email = TRIM(p_email);
    SET p_lecturer_id = TRIM(p_lecturer_id);
    SET p_l_msgv = TRIM(p_l_msgv);

    IF p_firstName = '' OR p_lastName = '' OR p_email = '' OR p_lecturer_id = '' OR p_l_msgv = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Vui lòng điền đủ các trường bắt buộc!';
    END IF;

    IF p_email NOT LIKE '%@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email phải có đuôi @hcmut.edu.vn!';
    END IF;

    IF p_sex IS NOT NULL AND p_sex NOT IN ('Male', 'Female', 'Other') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Giới tính không hợp lệ (Male, Female, Other)!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;

    -- Ghi nhận dữ liệu Thực thể Cha (User)
    INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality)
    VALUES (p_firstName, p_middleName, p_lastName, p_sex, p_email, p_birthday, p_nationality);

    SET v_user_id = LAST_INSERT_ID();

    -- Ghi nhận dữ liệu Thực thể Con (Lecturer)
    INSERT INTO Lecturer (id, lecturer_id, l_msgv)
    VALUES (v_user_id, p_lecturer_id, p_l_msgv);

    -- Cấp phát tài khoản xác thực (Authentication Record)
    INSERT INTO User_acc (ua_id, ua_username, ua_password, role_id)
    VALUES (v_user_id, p_l_msgv, SHA2(CONCAT(p_email, 'salt_bk'), 256), p_role_id);

    COMMIT;
END //

-- ==========================================
-- 5. CẬP NHẬT THÔNG TIN NGƯỜI DÙNG (Update Profile)
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

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. KIỂM TRA RÀNG BUỘC (VALIDATION)
    -- ==========================================
    SET p_firstName = TRIM(p_firstName);
    SET p_lastName = TRIM(p_lastName);

    IF p_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: User ID không được để trống!';
    END IF;

    IF p_firstName = '' OR p_lastName = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Họ và Tên không được để trống!';
    END IF;

    IF p_sex IS NOT NULL AND p_sex NOT IN ('Male', 'Female', 'Other') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Giới tính không hợp lệ!';
    END IF;

    -- Ràng buộc Tồn tại (Existence Check)
    IF NOT EXISTS (SELECT 1 FROM User WHERE id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Người dùng không tồn tại trong hệ thống!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
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
-- 6. ĐỔI MẬT KHẨU (Change Password)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_ChangePassword//

CREATE PROCEDURE sp_ChangePassword(
    IN p_user_id INT,
    IN p_old_password VARCHAR(255),
    IN p_new_password VARCHAR(255)
)
BEGIN
    DECLARE v_current_hash VARCHAR(255);
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. KIỂM TRA BẢO MẬT (SECURITY VALIDATION)
    -- ==========================================
    IF p_user_id IS NULL OR p_old_password = '' OR p_new_password = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Các trường mật khẩu không được để trống!';
    END IF;

    -- Ràng buộc độ phức tạp mật khẩu (Password Policy)
    IF CHAR_LENGTH(p_new_password) < 6 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Mật khẩu mới phải có ít nhất 6 ký tự!';
    END IF;

    -- Lấy mã băm hiện tại từ cơ sở dữ liệu
    SELECT ua_password INTO v_current_hash 
    FROM User_acc 
    WHERE ua_id = p_user_id;

    IF v_current_hash IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tài khoản không tồn tại!';
    END IF;

    -- Xác thực danh tính (Authentication Verification) bằng SHA256
    IF v_current_hash != SHA2(p_old_password, 256) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Mật khẩu cũ không chính xác!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    -- Cập nhật mật khẩu mới (Đã băm)
    UPDATE User_acc 
    SET ua_password = SHA2(p_new_password, 256)
    WHERE ua_id = p_user_id;

    COMMIT;
END //

-- ==========================================
-- 7. KHÓA TÀI KHOẢN (SOFT DELETE)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_ToggleUserStatus//

CREATE PROCEDURE sp_ToggleUserStatus(
    IN p_user_id INT,
    IN p_is_active BOOLEAN
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. KIỂM TRA RÀNG BUỘC (VALIDATION)
    -- ==========================================
    IF NOT EXISTS (SELECT 1 FROM User_acc WHERE ua_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tài khoản không tồn tại trong hệ thống!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    -- Thực hiện Xóa mềm (Soft Delete) bằng cách vô hiệu hóa cờ is_active
    UPDATE User_acc 
    SET is_active = p_is_active 
    WHERE ua_id = p_user_id;

    COMMIT;
END //

-- ==========================================
-- 8. XÓA NGƯỜI DÙNG VĨNH VIỄN (HARD DELETE)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_DeleteUser//

CREATE PROCEDURE sp_DeleteUser(
    IN p_user_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. KIỂM TRA RÀNG BUỘC (VALIDATION)
    -- ==========================================
    IF NOT EXISTS (SELECT 1 FROM User WHERE id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Người dùng không tồn tại!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    -- Thực hiện Xóa vật lý (Physical Delete). 
    -- Các bảng con sẽ tự động xóa theo cấu hình ON DELETE CASCADE.
    DELETE FROM User WHERE id = p_user_id;

    COMMIT;
END //

-- TRẢ LẠI DELIMITER VỀ DẤU CHẤM PHẨY MẶC ĐỊNH CHUẨN CÚ PHÁP
DELIMITER ;