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
    IN p_admin_id VARCHAR(20), -- Mã định danh nghiệp vụ của Admin (không phải PK)
    IN p_a_msqt VARCHAR(10),   -- Mã số quản trị (dùng làm username đăng nhập)
    OUT p_new_user_id INT      -- Trả về id User vừa được tạo
)
BEGIN
    DECLARE v_role_id INT;         -- Lưu role_id của Admin
    DECLARE v_salt VARCHAR(64);    -- Salt dùng để hash password
    DECLARE v_error_msg VARCHAR(512); -- Lưu thông báo lỗi hệ thống

    -- Handler cho lỗi trùng UNIQUE (email, admin_id, a_msqt, username...)
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Email, MSQT hoặc ID admin đã tồn tại!';
    END;

    -- Handler cho các lỗi SQL khác
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Validate domain email (business rule)
    IF TRIM(p_email) NOT LIKE '%@hcmut.edu.vn' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Email admin phải có đuôi @hcmut.edu.vn!';
    END IF;

    START TRANSACTION;

    -- Lấy role_id tương ứng với role 'Admin'
    SELECT role_id INTO v_role_id 
    FROM Role 
    WHERE role_name = 'Admin' 
    LIMIT 1;

    -- Nếu chưa cấu hình role trong hệ thống thì dừng
    IF v_role_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Hệ thống chưa cấu hình Role Admin!';
    END IF;

    -- 1. Tạo bản ghi trong bảng User (bảng cha)
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

    -- Lấy id vừa insert để dùng cho các bảng con
    SET p_new_user_id = LAST_INSERT_ID();

    -- 2. Tạo bản ghi trong bảng Admin (subclass của User)
    INSERT INTO Admin (id, admin_id, a_msqt)
    VALUES (
        p_new_user_id, 
        TRIM(p_admin_id), 
        TRIM(p_a_msqt)
    );

    -- 3. Tạo tài khoản đăng nhập trong User_acc
    -- Password được hash bằng SHA2(email + salt)
    SET v_salt = UUID();

    INSERT INTO User_acc (ua_id, ua_username, ua_password, salt, role_id, is_active)
    VALUES (
        p_new_user_id, 
        TRIM(p_a_msqt), 
        SHA2(CONCAT(TRIM(p_email), v_salt), 256), 
        v_salt, 
        v_role_id, 
        TRUE
    );

    COMMIT;
END //
DELIMITER ;