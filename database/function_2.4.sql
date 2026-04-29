USE elearning;


DELIMITER //
DROP FUNCTION IF EXISTS fn_MaxScore_Student_Test //

#hàm tìm max score của 1 học sinh trong 1 bài test, nếu không có attempt nào trả về NULL
CREATE FUNCTION fn_MaxScore_Student_Test(p_student_id INT, p_test_id INT)
RETURNS DECIMAL(7,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_max_score DECIMAL(7,2) DEFAULT NULL;
    DECLARE v_current_score DECIMAL(7,2);
    DECLARE v_done INT DEFAULT 0;
    
    DECLARE cur_attempts CURSOR FOR
        SELECT score
        FROM Attempt
        WHERE student_id = p_student_id AND test_id = p_test_id;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    
    #kiểm tra tồn tại không
    IF p_student_id IS NULL OR p_student_id <= 0 OR p_test_id IS NULL OR p_test_id <= 0 THEN
        RETURN NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Student WHERE id = p_student_id) THEN
        RETURN NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Test WHERE test_id = p_test_id) THEN
        RETURN NULL;
    END IF;

    OPEN cur_attempts;
    
    #logic tìm max
    score_loop: LOOP
        FETCH cur_attempts INTO v_current_score;
        
        IF v_done = 1 THEN
            LEAVE score_loop;
        END IF;
        
        -- IF logic to find maximum score
        IF v_current_score IS NOT NULL THEN
            IF v_max_score IS NULL OR v_current_score > v_max_score THEN
                SET v_max_score = v_current_score;
            END IF;
        END IF;
        
    END LOOP score_loop;
    
    CLOSE cur_attempts;
    
    RETURN v_max_score;
END //

-- Tính điểm trung bình và xếp loại sinh viên trong 1 lớp
DROP FUNCTION IF EXISTS fn_GetStudentGradeInClass //

CREATE FUNCTION fn_GetStudentGradeInClass(p_student_id INT, p_class_id INT)
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    DECLARE v_sum_score DECIMAL(10,2) DEFAULT 0;
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_cur_score DECIMAL(10,2);
    DECLARE v_avg DECIMAL(10, 2);
    DECLARE v_rank VARCHAR(20); -- Biến để lưu chuỗi xếp loại
    DECLARE is_done INT DEFAULT FALSE;

    -- Cursor lấy điểm các bài test
    DECLARE score_cursor CURSOR FOR
        SELECT score FROM Attempt
        WHERE student_id = p_student_id
        AND test_id IN (SELECT test_id FROM Test WHERE class_id = p_class_id);
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET is_done = TRUE;
    
    -- Kiểm tra tham số đầu vào
    IF p_student_id IS NULL OR p_class_id IS NULL THEN
        RETURN 'Invalid Input';
    END IF;
    
    OPEN score_cursor;
    score_loop: LOOP
        FETCH score_cursor INTO v_cur_score;
        IF is_done THEN
            LEAVE score_loop;
        END IF;
        
        SET v_sum_score = v_sum_score + COALESCE(v_cur_score, 0);
        SET v_count = v_count + 1;
    END LOOP;
    CLOSE score_cursor;
    
    IF v_count = 0 THEN 
        RETURN 'No Attempts Found';
    END IF;
    
    SET v_avg = v_sum_score / v_count;

    -- Gán giá trị xếp loại vào biến thay vì RETURN ngay
    IF v_avg >= 8.5 THEN SET v_rank = 'EXCELLENT';
    ELSEIF v_avg >= 7.0 THEN SET v_rank = 'GOOD';
    ELSEIF v_avg >= 5.5 THEN SET v_rank = 'FAIR';
    ELSEIF v_avg >= 4.0 THEN SET v_rank = 'PASS';
    ELSE SET v_rank = 'FAIL';
    END IF;

    -- Trả về chuỗi định dạng: "Điểm (Xếp loại)"
    RETURN CONCAT(FORMAT(v_avg, 2), ' [', v_rank, ']');
END //


-- Dem tong so file trong Lop hoc

DROP FUNCTION IF EXISTS fn_FileStatus //
CREATE FUNCTION fn_FileStatus(p_class_id INT)
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
	DECLARE v_total_file INT DEFAULT 0;
    DECLARE v_chapter_id INT;
    DECLARE v_sub_count INT;
    DECLARE is_done INT DEFAULT 0;
    
     
    -- Cursor fetching tat ca chapter trong class
    DECLARE chapter_cursor CURSOR FOR
		SELECT chapter_id 
        FROM Chapter 
        WHERE class_id = p_class_id;
	
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET is_done = TRUE;
    
	-- Kiem tra tham so dau vao
    IF p_class_id IS NULL THEN 
		RETURN 'INVALID INPUT';
	END IF;
    
	OPEN chapter_cursor;
    chapter_loop: LOOP
		FETCH chapter_cursor INTO v_chapter_id;
        IF is_done THEN LEAVE chapter_loop;
        END IF;
        
        SELECT COUNT(*) INTO v_sub_count
        FROM File
        WHERE class_id = p_class_id AND chapter_id = v_chapter_id;
        
        SET v_total_file = v_total_file + v_sub_count;
	END LOOP;
    CLOSE chapter_cursor;
    
    IF v_total_file = 0 THEN RETURN 'Lop hoc chua co tai lieu';
    ELSE RETURN CONCAT('Lop hoc co ', v_total_file, ' tai lieu');
    END IF;
END //
DELIMITER ;