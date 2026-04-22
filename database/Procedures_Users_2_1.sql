DELIMITER //

-- =====================================================================================
-- PROCEDURE: sp_CreateUser
-- MÔ TẢ:     Tạo mới một người dùng đầy đủ trong hệ thống.
-- ĐẦU VÀO:   Thông tin cá nhân (Họ tên, giới tính, email, ngày sinh, quốc tịch), 
--            Vai trò (Student/Lecturer/Admin), và Mã định danh (MSSV/MSGV/MSQT).
-- XỬ LÝ:     1. Xác thực Role và thông tin bắt buộc.
--            2. Lưu thông tin vào bảng cha `User`.
--            3. Lưu mã định danh vào bảng con tương ứng với Role.
--            4. Khởi tạo tài khoản đăng nhập (mật khẩu mặc định = mã định danh).
-- =====================================================================================
DROP PROCEDURE IF EXISTS sp_CreateUser//

CREATE PROCEDURE sp_CreateUser(
    IN p_role_name VARCHAR(20), 
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_email VARCHAR(100),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50),
    IN p_user_code VARCHAR(20), 
    OUT p_new_user_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- [EXCEPTION HANDLER]: Bắt riêng lỗi 1062 (Trùng lặp dữ liệu UNIQUE)
    -- Lỗi này sẽ nổ ra nếu Email hoặc Mã định danh (MSSV/MSGV) đã tồn tại
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email hoặc Mã số định danh đã tồn tại trong hệ thống!';
    END;
    -- [EXCEPTION HANDLER]: Rollback giao dịch và ném lỗi nếu có exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- [VALIDATION]: Xác minh vai trò người dùng thuộc danh sách cho phép
    IF p_role_name NOT IN ('Student', 'Lecturer', 'Admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Vai trò người dùng không hợp lệ (Phải là Student, Lecturer hoặc Admin)!';
    END IF;

    -- [VALIDATION]: Đảm bảo các thông tin định danh không bị rỗng
    IF TRIM(p_email) = '' OR TRIM(p_user_code) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email và Mã số định danh không được để trống!';
    END IF;

    START TRANSACTION;

    -- [BƯỚC 1]: Lưu trữ thông tin cá nhân cơ bản vào bảng `User`
    INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality)
    VALUES (TRIM(p_firstName), TRIM(p_middleName), TRIM(p_lastName), p_sex, TRIM(p_email), p_birthday, TRIM(p_nationality));
    
    SET p_new_user_id = LAST_INSERT_ID();

    -- [BƯỚC 2]: Phân bổ người dùng vào bảng chuyên biệt dựa theo Role
    IF p_role_name = 'Student' THEN
        INSERT INTO Student (id, s_mssv) VALUES (p_new_user_id, TRIM(p_user_code));
    ELSEIF p_role_name = 'Lecturer' THEN
        INSERT INTO Lecturer (id, l_msgv) VALUES (p_new_user_id, TRIM(p_user_code));
    ELSEIF p_role_name = 'Admin' THEN
        INSERT INTO Admin (id, a_msqt) VALUES (p_new_user_id, TRIM(p_user_code));
    END IF;

    -- [BƯỚC 3]: Thiết lập thông tin đăng nhập ban đầu vào bảng `User_acc`
    -- Lưu ý: Mật khẩu được băm bằng thuật toán SHA256
    INSERT INTO User_acc (ua_id, ua_username, ua_password)
    VALUES (p_new_user_id, TRIM(p_user_code), SHA2(TRIM(p_user_code), 256));

    COMMIT;
END//


-- =====================================================================================
-- PROCEDURE: sp_UpdateUserInfo
-- MÔ TẢ:     Cập nhật thông tin cá nhân của một người dùng đã tồn tại.
-- ĐẦU VÀO:   ID người dùng và toàn bộ thông tin cá nhân mới.
-- XỬ LÝ:     1. Kiểm tra tính duy nhất của Email mới.
--            2. Cập nhật dữ liệu tương ứng trong bảng `User`.
-- =====================================================================================
DROP PROCEDURE IF EXISTS sp_UpdateUserInfo//

CREATE PROCEDURE sp_UpdateUserInfo(
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

    -- [EXCEPTION HANDLER]: Rollback giao dịch và ném lỗi nếu có exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- [VALIDATION]: Tránh xung đột khóa Unique do email đã thuộc sở hữu của User khác
    IF EXISTS (SELECT 1 FROM User WHERE email = TRIM(p_email) AND id != p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email này đã được sử dụng bởi người dùng khác!';
    END IF;

    START TRANSACTION;
    
    -- [CẬP NHẬT]: Ghi đè thông tin mới vào bảng `User`
    UPDATE User 
    SET 
        firstName = TRIM(p_firstName),
        middleName = TRIM(p_middleName),
        lastName = TRIM(p_lastName),
        sex = p_sex,
        email = TRIM(p_email),
        birthday = p_birthday,
        nationality = TRIM(p_nationality)
    WHERE id = p_user_id;

    COMMIT;
END //


-- =====================================================================================
-- PROCEDURE: sp_ChangePassword
-- MÔ TẢ:     Thay đổi mật khẩu đăng nhập của người dùng.
-- ĐẦU VÀO:   ID người dùng, Mật khẩu cũ (plain text), Mật khẩu mới (plain text).
-- XỬ LÝ:     1. Xác minh độ dài tối thiểu của mật khẩu mới.
--            2. Đối chiếu hash mật khẩu cũ với dữ liệu đang lưu.
--            3. Cập nhật hash mật khẩu mới.
-- =====================================================================================
DROP PROCEDURE IF EXISTS sp_ChangePassword//

CREATE PROCEDURE sp_ChangePassword(
    IN p_user_id INT,
    IN p_old_password VARCHAR(255),
    IN p_new_password VARCHAR(255)
)
BEGIN
    DECLARE v_current_hash VARCHAR(255);
    DECLARE v_error_msg VARCHAR(512);

    -- [EXCEPTION HANDLER]: Rollback và ném lỗi (giới hạn thông báo 128 ký tự để bảo mật)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- [VALIDATION]: Đảm bảo không có trường nào bị bỏ trống
    IF p_user_id IS NULL OR p_old_password = '' OR p_new_password = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Các trường mật khẩu không được để trống!';
    END IF;

    -- [TRUY XUẤT]: Lấy mã băm mật khẩu hiện tại từ Database
    SELECT ua_password INTO v_current_hash
    FROM User_acc
    WHERE ua_id = p_user_id;

    IF v_current_hash IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tài khoản không tồn tại!';
    END IF;

    -- [XÁC THỰC]: Băm mật khẩu cũ người dùng nhập và so sánh với mã băm trong DB
    IF v_current_hash != SHA2(p_old_password, 256) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Mật khẩu cũ không chính xác!';
    END IF;

    START TRANSACTION;
    
    -- [CẬP NHẬT]: Mã hóa và lưu mật khẩu mới
    UPDATE User_acc 
    SET ua_password = SHA2(p_new_password, 256)
    WHERE ua_id = p_user_id;

    COMMIT;
END //


-- =====================================================================================
-- PROCEDURE: sp_DeleteUser
-- MÔ TẢ:     Xóa một người dùng khỏi hệ thống.
-- ĐẦU VÀO:   ID người dùng cần xóa.
-- XỬ LÝ:     Nhờ cơ chế ON DELETE CASCADE, chỉ cần xóa ở bảng cha `User`, 
--            dữ liệu ở các bảng con (Student/Lecturer/Admin, User_acc) sẽ tự động bị xóa.
-- =====================================================================================
DROP PROCEDURE IF EXISTS sp_DeleteUser//

CREATE PROCEDURE sp_DeleteUser(
    IN p_user_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- [EXCEPTION HANDLER]: Rollback giao dịch và ném lỗi nếu có exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    START TRANSACTION;
    
    -- [XÓA DỮ LIỆU]: Thực hiện xóa vật lý ở bảng gốc
    DELETE FROM User WHERE id = p_user_id;

    COMMIT;
END //

DELIMITER ;