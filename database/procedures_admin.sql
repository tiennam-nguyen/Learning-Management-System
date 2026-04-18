DELIMITER //

DROP PROCEDURE IF EXISTS sp_CreateAdmin//

CREATE PROCEDURE sp_CreateAdmin(
    IN p_firstName VARCHAR(50),
    IN p_middleName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_sex VARCHAR(10),
    IN p_email VARCHAR(100),
    IN p_birthday DATE,
    IN p_nationality VARCHAR(50),
    IN p_admin_id VARCHAR(20),
    IN p_a_msqt VARCHAR(10),
    IN p_role_id INT
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. CÁC BỘ XỬ LÝ LỖI (ERROR HANDLERS)
    -- ==========================================
    
    -- Bắt lỗi vi phạm ràng buộc UNIQUE (Duplicate Entry - Mã 1062)
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email, MSQT hoặc Admin ID đã tồn tại trong hệ thống!';
    END;

    -- Bắt các ngoại lệ SQL chung và cắt chuỗi để tránh lỗi 'Data too long'
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. CHUẨN HÓA VÀ KIỂM TRA DỮ LIỆU ĐẦU VÀO (VALIDATION)
    -- ==========================================
    
    -- Loại bỏ khoảng trắng thừa ở hai đầu chuỗi
    SET p_firstName = TRIM(p_firstName);
    SET p_lastName = TRIM(p_lastName);
    SET p_email = TRIM(p_email);
    SET p_admin_id = TRIM(p_admin_id);
    SET p_a_msqt = TRIM(p_a_msqt);

    -- Đảm bảo các trường bắt buộc không bị bỏ trống
    IF p_firstName = '' OR p_lastName = '' OR p_email = '' OR p_admin_id = '' OR p_a_msqt = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Vui lòng điền đủ các trường thông tin bắt buộc!';
    END IF;

    -- Ràng buộc nghiệp vụ: Email phải thuộc hệ thống ĐH Bách Khoa
    IF p_email NOT LIKE '%@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email phải có đuôi @hcmut.edu.vn!';
    END IF;

    -- Ràng buộc toàn vẹn: Giới tính phải khớp với tập giá trị ENUM
    IF p_sex IS NOT NULL AND p_sex NOT IN ('Male', 'Female', 'Other') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Giới tính không hợp lệ (Chỉ nhận Male, Female, hoặc Other)!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    
    -- Đảm bảo tính toàn vẹn All-or-Nothing
    START TRANSACTION;

    -- Bước 3.1: Lưu thông tin cơ bản vào bảng User (Thực thể cha)
    INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality)
    VALUES (p_firstName, p_middleName, p_lastName, p_sex, p_email, p_birthday, p_nationality);

    -- Lấy ID tự động sinh ra từ bảng User để làm khóa ngoại cho bảng con
    SET v_user_id = LAST_INSERT_ID();

    -- Bước 3.2: Lưu thông tin định danh riêng vào bảng Admin (Thực thể con)
    INSERT INTO Admin (id, admin_id, a_msqt)
    VALUES (v_user_id, p_admin_id, p_a_msqt);

    -- Bước 3.3: Cấp phát tài khoản đăng nhập (Sử dụng MSQT làm Username, băm mật khẩu SHA256)
    INSERT INTO User_acc (ua_id, ua_username, ua_password, role_id)
    VALUES (v_user_id, p_a_msqt, SHA2(CONCAT(p_email, 'salt_bk'), 256), p_role_id);

    COMMIT;
END //

DELIMITER ;