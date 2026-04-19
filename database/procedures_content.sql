-- ==========================================
-- NỘI DUNG HỌC TẬP (COURSE CONTENT)
-- Xử lý thực thể yếu: Chapter (phụ thuộc Class) và Topic (phụ thuộc Chapter)
-- ==========================================

DELIMITER //

-- ==========================================
-- QUẢN LÝ CHƯƠNG HỌC (CHAPTER)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateChapter//

CREATE PROCEDURE sp_CreateChapter(
    IN p_class_id INT,
    IN p_chapter_name VARCHAR(255),
    OUT p_new_chapter_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512); -- Lưu thông báo lỗi hệ thống

    -- Handler lỗi SQL (rollback toàn bộ transaction)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK; 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    START TRANSACTION;
    
    -- Lock bản ghi Class để tránh race condition khi nhiều request cùng tạo Chapter
    IF NOT EXISTS (
        SELECT 1 
        FROM Class 
        WHERE class_id = p_class_id 
        FOR UPDATE
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- Sinh chapter_id theo scope của class (composite key)
    SELECT COALESCE(MAX(chapter_id), 0) + 1 
    INTO p_new_chapter_id 
    FROM Chapter 
    WHERE class_id = p_class_id;

    -- Tạo Chapter mới
    INSERT INTO Chapter (class_id, chapter_id, chapter_name)
    VALUES (
        p_class_id, 
        p_new_chapter_id, 
        TRIM(p_chapter_name)
    );

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_DeleteChapter//

CREATE PROCEDURE sp_DeleteChapter(
    IN p_class_id INT,
    IN p_chapter_id INT
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

    -- Kiểm tra tồn tại Chapter
    IF NOT EXISTS (
        SELECT 1 
        FROM Chapter 
        WHERE class_id = p_class_id 
          AND chapter_id = p_chapter_id
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Chương học không tồn tại!';
    END IF;

    START TRANSACTION;

    -- Xóa Chapter (Topic và File sẽ tự xóa theo ON DELETE CASCADE)
    DELETE FROM Chapter 
    WHERE class_id = p_class_id 
      AND chapter_id = p_chapter_id;

    COMMIT;
END //

-- ==========================================
-- QUẢN LÝ CHỦ ĐỀ HỌC TẬP (TOPIC)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateTopic//

CREATE PROCEDURE sp_CreateTopic(
    IN p_class_id INT,
    IN p_chapter_id INT,
    IN p_topic_name VARCHAR(255),
    IN p_topic_content TEXT,
    OUT p_new_topic_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Chuẩn hóa và validate input
    SET p_topic_name = TRIM(p_topic_name);

    IF p_topic_name = '' OR p_class_id IS NULL OR p_chapter_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tên chủ đề, ID Lớp và ID Chương không được trống!';
    END IF;

    START TRANSACTION;
    
    -- Lock Chapter để đảm bảo tính nhất quán khi sinh topic_id
    IF NOT EXISTS (
        SELECT 1 
        FROM Chapter 
        WHERE class_id = p_class_id 
          AND chapter_id = p_chapter_id 
        FOR UPDATE
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Chương học cha không tồn tại!';
    END IF;
    
    -- Sinh topic_id theo scope (class_id, chapter_id)
    SELECT COALESCE(MAX(topic_id), 0) + 1 
    INTO p_new_topic_id 
    FROM Topic 
    WHERE class_id = p_class_id 
      AND chapter_id = p_chapter_id;

    -- Tạo Topic mới
    INSERT INTO Topic (class_id, chapter_id, topic_id, topic_name, topic_content)
    VALUES (
        p_class_id, 
        p_chapter_id, 
        p_new_topic_id, 
        p_topic_name, 
        p_topic_content
    );

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_UpdateTopic//

CREATE PROCEDURE sp_UpdateTopic(
    IN p_class_id INT,
    IN p_chapter_id INT,
    IN p_topic_id INT,
    IN p_topic_name VARCHAR(255),
    IN p_topic_content TEXT
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

    -- Kiểm tra tồn tại Topic
    IF NOT EXISTS (
        SELECT 1 
        FROM Topic 
        WHERE class_id = p_class_id 
          AND chapter_id = p_chapter_id 
          AND topic_id = p_topic_id
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Chủ đề không tồn tại!';
    END IF;

    START TRANSACTION;
    
    -- Cập nhật nội dung Topic
    UPDATE Topic 
    SET 
        topic_name = TRIM(p_topic_name),
        topic_content = p_topic_content
    WHERE class_id = p_class_id 
      AND chapter_id = p_chapter_id 
      AND topic_id = p_topic_id;

    COMMIT;
END //

DELIMITER ;