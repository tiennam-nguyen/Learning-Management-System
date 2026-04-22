DELIMITER //
CREATE TRIGGER trg_AutoAttemptIndex_Insert
BEFORE INSERT ON Attempt
FOR EACH ROW
BEGIN
    DECLARE v_next_index INT;
    
    -- Tìm số thứ tự lần thi lớn nhất hiện tại, nếu chưa thi lần nào thì COALESCE trả về 0 -> 0 + 1 = 1
    SELECT COALESCE(MAX(attempt_index), 0) + 1 INTO v_next_index
    FROM Attempt
    WHERE test_id = NEW.test_id AND student_id = NEW.student_id;
    
    SET NEW.attempt_index = v_next_index;
END//

CREATE TRIGGER trg_AutoCalcTimer_Update
BEFORE UPDATE ON Attempt
FOR EACH ROW
BEGIN
    -- Nếu trạng thái là đang nộp bài (end_time được cập nhật từ NULL thành có giá trị)
    IF NEW.end_time IS NOT NULL AND OLD.end_time IS NULL THEN
        -- Tự động tính khoảng cách bằng GIÂY
        SET NEW.timer = TIMESTAMPDIFF(SECOND, NEW.start_time, NEW.end_time);
    END IF;
END//
DELIMITER ;