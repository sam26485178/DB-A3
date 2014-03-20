DB A3 

export TDSVER=8.0
tsql -U adrice\\qd2 -H classdb.ad.rice.edu -p 1433

problem 1

1 code:

CREATE TRIGGER dateGap
ON climbed for INSERT AS BEGIN
DECLARE @dayG datetime
DECLARE @pname VARCHAR(30)
DECLARE @dateG int
DECLARE @TID int
select @dayG = [WHEN_CLIMBED] from inserted
select @TID = [TRIP_ID] from inserted
select @pname = [peak] from inserted
select @dateG =  
(select min(abs(datediff(day,@dayG,c.WHEN_CLIMBED)))
from climbed as c
where c.TRIP_ID = @TID AND c.peak <> @pname)
if @dateG > 20
begin
	PRINT 'The climb you inserted is ' + cast(@dateG as varchar(11)) + ' days from the closest existing climb in trip ' + cast(@TID as varchar(11))
END
END

test:

INSERT INTO climbed VALUES (1, 'Kearsarge Peak', '06/28/2002');
INSERT INTO climbed VALUES (6, 'Mount Guyot', '06/21/2002');
INSERT INTO climbed VALUES (23, 'Lion Rock', '08/09/2004');
INSERT INTO climbed VALUES (23, 'Mount Williamson', '06/09/2004');
INSERT INTO climbed VALUES (29, 'Lion Rock', '06/09/2004');


2 code:

CREATE TRIGGER rmTrip
ON participated for delete AS BEGIN
DECLARE @TID int
SELECT @TID = [TRIP_ID] FROM deleted
IF @TID NOT IN (
	SELECT p.trip_id
	from participated AS p
)
BEGIN
	DELETE FROM climbed
	WHERE trip_id = @TID
END
END

test:

DELETE FROM participated WHERE trip_id = 12;
SELECT COUNT(*) FROM climbed WHERE trip_id = 12;

DELETE FROM participated WHERE trip_id = 13 AND name <> 'ELIZABETH';
SELECT COUNT(*) FROM climbed WHERE trip_id = 13;

DELETE FROM participated WHERE name = 'ELIZABETH';
SELECT COUNT(*) FROM climbed WHERE trip_id = 13;

SELECT COUNT (DISTINCT trip_id) FROM climbed;
DELETE FROM participated WHERE trip_id IN
  (SELECT trip_id FROM participated WHERE name = 'LINDA');
SELECT COUNT (DISTINCT trip_id) FROM climbed;


problem 2

code:

CREATE TRIGGER insertMatch
ON climbed for INSERT AS BEGIN
DECLARE @iname VARCHAR(30)
DECLARE @cutoff int;

SELECT @cutoff = [cutoff] FROM ed_cutoff
SELECT @iname = [PEAK] FROM INSERTED

IF @iname NOT IN (
	SELECT PEAK.NAME 
	FROM PEAK
)
BEGIN
	DECLARE myPeak CURSOR FOR
	SELECT PEAK.NAME FROM PEAK
 	
	DECLARE @lname VARCHAR(30)
	OPEN myPeak

	FETCH NEXT FROM myPeak INTO @lname

	WHILE (@@FETCH_STATUS = 0)
 	BEGIN
 		DECLARE @array table ( i int, j int, value int);
 		DECLARE @iv VARCHAR(1), @lv VARCHAR(1);
 		DECLARE @inameLen int, @lnameLen int, @i int, @j int, @nextV int, @tmp int, @flag int;
 		DECLARE @tmp1 int, @tmp2 int, @tmp3 int;

 		SET @inameLen = len(@iname);
 		SET @lnameLen = len(@lname);
 		SET @i = 0;
 		SET @j = 0;
 		set @flag = 0;

 		WHILE @i <= @inameLen
 		BEGIN
 			INSERT @array(i, j, [value])
 			VALUES(@i, 0, @i);
 			SET @i = @i + 1;
 		END
 		WHILE @j <= @lnameLen
 		BEGIN
 			INSERT @array(i, j, [value])
 			VALUES(0,@j,@j);
 			SET @j = @j + 1;
 		END

 		SET @i = 1;
 		SET @j = 1;

 		WHILE @i <= @inameLen
		BEGIN
			SET @iv = SUBSTRING(@iname, @i, 1)
			WHILE @j <= @lnameLen
			BEGIN
				SET @lv = SUBSTRING(@lname, @j, 1)
				IF @iv = @lv
				BEGIN
					SELECT @nextV = value
					FROM @array a WHERE a.i = @i -1 AND a.j = @j -1
				END
				ELSE
				BEGIN
					SELECT @tmp1 = value+1
					FROM @array a WHERE a.i = @i -1 AND a.j = @j
					SELECT @tmp2 = value+1
					FROM @array a WHERE a.i = @i AND a.j = @j-1
					SELECT @tmp3 = value+1
					FROM @array a WHERE a.i = @i -1 AND a.j = @j-1
					IF @tmp1 <= @tmp2 SELECT @nextV = @tmp1
					ELSE SELECT @nextV = @tmp2
					IF @tmp3 <= @nextV SELECT @nextV = @tmp3
				END
				INSERT @array(i,j,[value])
				VALUES(@i,@j,@nextV);
				SET @j = @j + 1;
			END
			SET @i = @i + 1;
			SET @j = 1;
		END 		

		IF @inameLen > @lnameLen SELECT @tmp = @inameLen
		ELSE SELECT @tmp = @lnameLen

		SELECT @nextV = value
		FROM @array a WHERE a.i = @inameLen AND a.j = @lnameLen

		IF @nextV <= @cutoff 
		BEGIN
			set @flag = 1;
			PRINT 'ERROR: Inserted peak name ''' + @iname + ''' does not match any in the database. ''' + @lname + ''' is used instead.'
			UPDATE climbed
			SET PEAK = @lname
			WHERE PEAK = @iname
			break;
		END
		DELETE FROM @array
		FETCH NEXT FROM myPeak INTO @lname
 	END
 	CLOSE myPeak;
 	DEALlOCATE myPeak;
END
IF @flag = 0
BEGIN
PRINT 'ERROR: Inserted peak name ''' + @iname + '''does not closely match any in the database, and so the insert is rejected'
ROLLBACK TRANSACTION
END
END

test:

CREATE TABLE ed_cutoff (cutoff INT);
INSERT INTO ed_cutoff VALUES (3);

INSERT INTO climbed VALUES (30, 'North Guard', '09/06/2002');
INSERT INTO climbed VALUES (30, 'Home Nose', '09/06/2002');
SELECT * FROM climbed WHERE trip_id = 30;

INSERT INTO climbed VALUES (31, 'Moses Mount', '09/06/2002');
INSERT INTO climbed VALUES (31, 'Olancha Mountain', '09/06/2002');
INSERT INTO climbed VALUES (31, 'Mt. Hitchcock', '09/06/2002');
INSERT INTO climbed VALUES (31, 'Mt Hitchcock', '09/06/2002');
INSERT INTO climbed VALUES (31, 'Milestoan Mounten', '09/06/2002');
INSERT INTO climbed VALUES (31, 'Milestoan Mountan', '09/06/2002');
SELECT * FROM climbed WHERE trip_id = 31;

DROP TABLE ed_cutoff;
CREATE TABLE ed_cutoff (cutoff INT);
INSERT INTO ed_cutoff VALUES (2);

INSERT INTO climbed VALUES (32, 'Piket Gard Peak', '09/06/2002');
INSERT INTO climbed VALUES (32, 'Milestoan Mounten', '09/06/2002');
INSERT INTO climbed VALUES (32, 'Milestoan Mountain', '09/06/2002');
SELECT * FROM climbed WHERE trip_id = 32;

