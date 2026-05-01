USE elearning;

DELIMITER //
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

-- @Test trang thai tai lieu 
SELECT 
    c.class_id AS Class_ID,
    c.class_name AS Class_name,
    s.subject_name AS Subject_name,
    fn_FileStatus(c.class_id) AS Trang_Thai_Tai_Lieu
FROM Class c
JOIN Subject s ON c.subject_id = s.subject_id;