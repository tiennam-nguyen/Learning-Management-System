DELIMITER //

-- ==============================================================================
-- PHẦN: TRIGGER XỬ LÝ DỮ LIỆU DẪN XUẤT TRONG BẢNG Attempt
-- Bao gồm:
--  (1) Tự động xác định số lần làm bài (attempt_index)
--  (2) Tự động tính thời gian làm bài (timer)
-- Các trigger được thiết kế chạy TRƯỚC các trigger validation tương ứng
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- TRIGGER 1: trg_AutoAttemptIndex_Insert
-- Sự kiện: BEFORE INSERT trên bảng Attempt
-- Chức năng:
--   - Tự động sinh giá trị attempt_index (lần làm bài)
--   - Đảm bảo mỗi (student_id, test_id) có thứ tự lần thi tăng dần
--   - Thuộc tính attempt_index được xem là thuộc tính dẫn xuất
-- Thứ tự thực thi:
--   - Sử dụng PRECEDES để đảm bảo chạy trước trigger validation thời gian
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_AutoAttemptIndex_Insert//

CREATE TRIGGER trg_AutoAttemptIndex_Insert
BEFORE INSERT ON Attempt
FOR EACH ROW
PRECEDES trg_check_attempt_time_insert
BEGIN
    DECLARE v_next_index INT;
    
    -- [Bước 1] Xác định lần thi hiện tại lớn nhất của sinh viên cho bài test
    -- Nếu chưa tồn tại lần thi nào → MAX = NULL → COALESCE về 0
    SELECT COALESCE(MAX(attempt_index), 0) + 1
    INTO v_next_index
    FROM Attempt
    WHERE test_id = NEW.test_id 
        AND student_id = NEW.student_id;
    
    -- [Bước 2] Gán giá trị attempt_index cho bản ghi mới
    SET NEW.attempt_index = v_next_index;
END//


-- ------------------------------------------------------------------------------
-- TRIGGER 2: trg_AutoCalcTimer_Update
-- Sự kiện: BEFORE UPDATE trên bảng Attempt
-- Chức năng:
--   - Tự động tính toán thời gian làm bài (timer)
--   - timer được tính bằng số giây giữa start_time và end_time
--   - Thuộc tính timer là thuộc tính dẫn xuất (derived attribute)
-- Điều kiện kích hoạt logic:
--   - Chỉ tính khi end_time chuyển từ NULL → NOT NULL (tức là lúc nộp bài)
-- Thứ tự thực thi:
--   - PRECEDES đảm bảo chạy trước trigger validation liên quan đến thời gian
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_AutoCalcTimer_Update//

CREATE TRIGGER trg_AutoCalcTimer_Update
BEFORE UPDATE ON Attempt
FOR EACH ROW
PRECEDES trg_check_attempt_time_update
BEGIN
    -- [Bước 1] Kiểm tra sự kiện "nộp bài"
    -- end_time được gán lần đầu (trước đó là NULL)
    IF NEW.end_time IS NOT NULL AND OLD.end_time IS NULL THEN
        
        -- [Bước 2] Tính toán thời gian làm bài (đơn vị: giây)
        SET NEW.timer = TIMESTAMPDIFF(
            SECOND, 
            NEW.start_time, 
            NEW.end_time
        );
    END IF;
END//

DELIMITER ;