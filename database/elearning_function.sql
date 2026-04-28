USE elearning;

-- Tính điểm trung bình và xếp loại sinh viên trong 1 lớp
DELIMITER $$

DROP FUNCTION IF EXISTS fn_GetStudentGradeInClass $$

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
END $$

DELIMITER ;

-- Dem tong so file trong Lop hoc

DELIMITER $$
DROP FUNCTION IF EXISTS fn_FileStatus $$
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
END $$
DELIMITER ;


-- @Test trả về điểm trung bình và xếp loại sinh viên trong lớp 1
SELECT 
    u.id AS User_ID,
    CONCAT(u.lastName, ' ', u.firstName) AS Full_Name,
    s.s_mssv AS MSSV,
    fn_GetStudentGradeInClass(u.id, 1) AS Academic_Rank
FROM User u
JOIN Student s ON u.id = s.id
JOIN Enrollment e ON s.id = e.student_id
WHERE e.class_id = 1;

-- @Test trang thai tai lieu 
SELECT 
    c.class_id AS Class_ID,
    c.class_name AS Class_name,
    s.subject_name AS Subject_name,
    fn_FileStatus(c.class_id) AS Trang_Thai_Tai_Lieu
FROM Class c
JOIN Subject s ON c.subject_id = s.subject_id;