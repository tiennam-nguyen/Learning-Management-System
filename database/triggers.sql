DELIMITER //

DROP TRIGGER IF EXISTS trg_AutoAttemptIndex_Insert//
CREATE TRIGGER trg_AutoAttemptIndex_Insert
BEFORE INSERT ON Attempt
FOR EACH ROW
BEGIN
    DECLARE v_next_index INT;

    -- Tìm lượt thi lớn nhất hiện tại của sinh viên đó trong bài Test này
    SELECT COALESCE(MAX(attempt_index), 0) + 1 INTO v_next_index
    FROM Attempt
    WHERE test_id = NEW.test_id AND student_id = NEW.student_id;

    -- Tự động gán giá trị tính được vào dòng dữ liệu chuẩn bị được Insert
    SET NEW.attempt_index = v_next_index;
END //

DELIMITER ;