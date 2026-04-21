USE elearningdb;

-- Tính điểm trung bình và xếp loại sinh viên trong 1 lớp
DELIMITER $$
DROP FUNCTION IF EXISTS fn_GetStudentGradeInClass;
CREATE FUNCTION fn_GetStudentGradeInClass(p_student_id INT, p_class_id INT)
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
	DECLARE v_sum_score DECIMAL(10,2) DEFAULT 0;
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_cur_score DECIMAL(10,2);
    DECLARE v_avg DECIMAL(10, 2);
    DECLARE is_done INT DEFAULT FALSE;

	-- Cursor lay diem cac bai test
    DECLARE score_cursor CURSOR FOR
		SELECT total_score FROM Attempt
        WHERE student_id = p_student_id
        AND test_id IN (SELECT test_id FROM test WHERE class_id = p_class_id);
        
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET is_done = TRUE;
    
    -- Kiem tra tham so dau vao
    IF p_student_id IS NULL OR p_class_id IS NULL THEN
		RETURN 'Invalid Input';
	END IF;
    
    OPEN score_cursor;
    
    score_loop: LOOP
		FETCH score_cursor INTO v_cur_score;
        IF is_done THEN
			LEAVE score_loop;
		END IF;
        
        SET v_sum_score = v_sum_score + v_cur_score;
        SET v_count = v_count + 1;
	END LOOP;
	CLOSE score_cursor;
    
    IF v_count = 0 THEN 
		RETURN 'NONE DATA';
	END IF;
    
    SET v_avg = v_sum_score / v_count;
    IF v_avg >= 8.5 THEN RETURN 'EXCELLENT';
    ELSEIF v_avg >= 7.0 THEN RETURN 'GOOD';
    ELSEIF v_avg >= 5.5 THEN RETURN 'FAIR';
    ELSEIF v_avg >= 4.0 THEN RETURN 'PASS';
    ELSE RETURN 'FAIL';
    END IF;
END $$
DELIMITER ;

-- Dem tong so file trong Lop hoc

DELIMITER $$
DROP FUNCTION IF EXISTS fn_FileStatus;
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
    
    IF v_total_file = 0 THEN RETURN 'Lớp học chưa có tài liệu';
    ELSE RETURN CONCAT('Lớp học có ', v_total_file, ' tài liệu');
    END IF;
END $$
DELIMITER ;