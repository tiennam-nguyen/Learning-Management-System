-- ==========================================
-- CLASS INTERACTION (TƯƠNG TÁC LỚP HỌC)
-- Bao gồm:
--   - Post: Bài đăng / thảo luận trong lớp
--   - Comment: Bình luận trên bài đăng
-- ==========================================

DELIMITER //

-- ==========================================
-- 7.1. POST MANAGEMENT (QUẢN LÝ BÀI ĐĂNG)
-- ==========================================

DROP PROCEDURE IF EXISTS sp_CreatePost//

CREATE PROCEDURE sp_CreatePost(
    IN p_post_name VARCHAR(255),
    IN p_post_description TEXT,
    IN p_post_start DATETIME,
    IN p_post_end DATETIME,
    IN p_ua_id INT,
    IN p_class_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- ERROR HANDLER: rollback + trả lỗi ngắn gọn
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- VALIDATION: dữ liệu đầu vào cơ bản
    -- ==========================================
    SET p_post_name = TRIM(p_post_name);
    IF p_post_name = '' OR p_ua_id IS NULL OR p_class_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tiêu đề, ID Người dùng và ID Lớp không được để trống!';
    END IF;

    -- ==========================================
    -- VALIDATION: logic thời gian (nếu có set lịch)
    -- ==========================================
    IF p_post_start IS NOT NULL AND p_post_end IS NOT NULL THEN
        IF p_post_start >= p_post_end THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Lỗi Logic: Thời gian kết thúc phải sau thời gian bắt đầu!';
        END IF;
    END IF;

    -- ==========================================
    -- VALIDATION: kiểm tra khóa ngoại
    -- ==========================================
    IF NOT EXISTS (SELECT 1 FROM User_acc WHERE ua_id = p_ua_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tài khoản người dùng không tồn tại!';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Class WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- ==========================================
    -- TRANSACTION: tạo bài đăng
    -- ==========================================
    START TRANSACTION;

    INSERT INTO Post (post_name, post_description, post_start, post_end, ua_id, class_id)
    VALUES (p_post_name, p_post_description, p_post_start, p_post_end, p_ua_id, p_class_id);

    COMMIT;
END //


DROP PROCEDURE IF EXISTS sp_UpdatePost//

CREATE PROCEDURE sp_UpdatePost(
    IN p_post_id INT,
    IN p_post_name VARCHAR(255),
    IN p_post_description TEXT,
    IN p_ua_id INT -- ID người thực hiện (dùng để check quyền)
)
BEGIN
    DECLARE v_owner_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- VALIDATION: kiểm tra tồn tại + lấy owner
    -- ==========================================
    SELECT ua_id INTO v_owner_id 
    FROM Post 
    WHERE post_id = p_post_id;
    
    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài đăng không tồn tại!';
    END IF;

    -- ==========================================
    -- AUTHORIZATION: chỉ owner được sửa
    -- ==========================================
    IF v_owner_id != p_ua_id THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Phân quyền: Không được sửa bài của người khác!';
    END IF;

    -- ==========================================
    -- TRANSACTION: cập nhật bài đăng
    -- ==========================================
    START TRANSACTION;

    UPDATE Post 
    SET post_name = TRIM(p_post_name),
        post_description = p_post_description
    WHERE post_id = p_post_id;

    COMMIT;
END //


DROP PROCEDURE IF EXISTS sp_DeletePost//

CREATE PROCEDURE sp_DeletePost(
    IN p_post_id INT,
    IN p_req_ua_id INT 
)
BEGIN
    DECLARE v_owner_id INT;
    DECLARE v_req_role VARCHAR(50);
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK; 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    START TRANSACTION;

    -- ==========================================
    -- LOCK + VALIDATION: kiểm tra tồn tại (chưa bị xóa)
    -- ==========================================
    SELECT ua_id INTO v_owner_id 
    FROM Post 
    WHERE post_id = p_post_id AND is_deleted = FALSE 
    FOR UPDATE;

    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài đăng không tồn tại hoặc đã xóa!';
    END IF;

    -- ==========================================
    -- Lấy role của người thực hiện
    -- ==========================================
    SELECT r.role_name INTO v_req_role 
    FROM User_acc u 
    JOIN Role r ON u.role_id = r.role_id 
    WHERE u.ua_id = p_req_ua_id;

    -- ==========================================
    -- AUTHORIZATION: Owner hoặc Admin
    -- ==========================================
    IF v_owner_id != p_req_ua_id AND v_req_role != 'Admin' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Quyền: Chỉ tác giả hoặc Admin được xóa!';
    END IF;

    -- ==========================================
    -- SOFT DELETE: không xóa vật lý
    -- ==========================================
    UPDATE Post 
    SET is_deleted = TRUE 
    WHERE post_id = p_post_id;

    COMMIT;
END //


-- ==========================================
-- 7.2. COMMENT MANAGEMENT (QUẢN LÝ BÌNH LUẬN)
-- ==========================================

DROP PROCEDURE IF EXISTS sp_CreateComment//

CREATE PROCEDURE sp_CreateComment(
    IN p_comment_content TEXT,
    IN p_post_id INT,
    IN p_ua_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- VALIDATION: nội dung không rỗng
    -- ==========================================
    IF TRIM(p_comment_content) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Nội dung bình luận không được để trống!';
    END IF;

    -- VALIDATION: tồn tại post
    IF NOT EXISTS (SELECT 1 FROM Post WHERE post_id = p_post_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài đăng không tồn tại!';
    END IF;
    
    -- VALIDATION: tồn tại user
    IF NOT EXISTS (SELECT 1 FROM User_acc WHERE ua_id = p_ua_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tài khoản không hợp lệ!';
    END IF;

    -- ==========================================
    -- TRANSACTION: tạo comment
    -- ==========================================
    START TRANSACTION;

    INSERT INTO Comment (comment_content, post_id, ua_id)
    VALUES (TRIM(p_comment_content), p_post_id, p_ua_id);

    COMMIT;
END //


-- ==========================================
-- UPDATE COMMENT
-- ==========================================
DROP PROCEDURE IF EXISTS sp_UpdateComment//

CREATE PROCEDURE sp_UpdateComment(
    IN p_comment_id INT,
    IN p_comment_content TEXT,
    IN p_ua_id INT -- ID người thao tác (check quyền)
)
BEGIN
    DECLARE v_owner_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- VALIDATION: nội dung
    IF TRIM(p_comment_content) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Nội dung bình luận không được để trống!';
    END IF;

    -- VALIDATION + OWNER CHECK
    SELECT ua_id INTO v_owner_id 
    FROM Comment 
    WHERE comment_id = p_comment_id;
    
    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bình luận không tồn tại!';
    END IF;

    -- AUTHORIZATION: chỉ owner
    IF v_owner_id != p_ua_id THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Phân quyền: Không được sửa bình luận người khác!';
    END IF;

    -- TRANSACTION
    START TRANSACTION;

    UPDATE Comment 
    SET comment_content = TRIM(p_comment_content)
    WHERE comment_id = p_comment_id;

    COMMIT;
END //


DROP PROCEDURE IF EXISTS sp_DeleteComment//

CREATE PROCEDURE sp_DeleteComment(
    IN p_comment_id INT,
    IN p_req_ua_id INT
)
BEGIN
    DECLARE v_owner_id INT;
    DECLARE v_req_role VARCHAR(50);
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    START TRANSACTION;

    -- LOCK + VALIDATION
    SELECT ua_id INTO v_owner_id 
    FROM Comment 
    WHERE comment_id = p_comment_id AND is_deleted = FALSE 
    FOR UPDATE;

    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bình luận không tồn tại hoặc đã bị xóa!';
    END IF;

    -- Lấy role
    SELECT r.role_name INTO v_req_role 
    FROM User_acc u 
    JOIN Role r ON u.role_id = r.role_id 
    WHERE u.ua_id = p_req_ua_id;

    -- AUTHORIZATION: Owner hoặc Admin
    IF v_owner_id != p_req_ua_id AND v_req_role != 'Admin' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Phân quyền: Không thể xóa bình luận người khác!';
    END IF;

    -- SOFT DELETE
    UPDATE Comment 
    SET is_deleted = TRUE 
    WHERE comment_id = p_comment_id;

    COMMIT;
END //

DELIMITER ;