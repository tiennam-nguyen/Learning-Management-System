DELIMITER //

-- ------------------------------------------------------------------------------
-- TRIGGER : trg_AutoAttemptIndex_Insert
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

