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

problem 3

code:

CREATE PROCEDURE FindMostSimilar
AS BEGIN
DECLARE @numOfP int;
DECLARE @firstN VARCHAR(30), @secondN VARCHAR(30);
DECLARE @i int, @j int;
DECLARE @nOfFirstPeak int, @nOfSecondPeak int;
DECLARE @nextV int;
DECLARE @BestfEachPerson table (mName VARCHAR(30), yName VARCHAR(30), value int);
DECLARE @tmp int, @tmp1 int, @tmp2 int;
DECLARE @ii int, @jj int;
DECLARE @iv VARCHAR(30), @lv VARCHAR(30);

SET @i = 1;
SET @j = 1;
SET @nOfFirstPeak = 0;
SET @nOfSecondPeak = 0;

SELECT @numOfP = COUNT(DISTINCT p.name)
FROM PARTICIPATED AS P

WHILE @i <= @numOfP -1
BEGIN
	SET @j = @i + 1
	DECLARE @LCSOfEachPerson table (mName VARCHAR(30), yName VARCHAR(30), value int);
	WHILE @j <= @numOfP
	BEGIN
		DECLARE @array table ( i int, j int, value int);
		SET @ii = 0;
		SET @jj = 0;

		SELECT @firstN = ppp.name from(
			SELECT ROW_NUMBER() OVER (order by pp.name) AS ROWNUM, pp.name
			FROM (
			SELECT DISTINCT p.name FROM participated AS p) AS pp) AS ppp
			WHERE ppp.ROWNUM = @i

		SELECT @secondN = ppp.name from(
			SELECT ROW_NUMBER() OVER (order by pp.name) AS ROWNUM, pp.name
			FROM (
			SELECT DISTINCT p.name FROM participated AS p) AS pp) AS ppp
			WHERE ppp.ROWNUM = @j

		SELECT @nOfFirstPeak = COUNT(*)
			FROM participated AS p, climbed AS c
			WHERE p.name = @firstN AND p.trip_id = c.trip_id

		SELECT @nOfSecondPeak = COUNT(*)
			FROM participated AS p, climbed AS c
			WHERE p.name = @secondN AND p.trip_id = c.trip_id

		WHILE @ii <= @nOfFirstPeak
 		BEGIN
 			INSERT @array(i, j, [value])
 			VALUES(@ii, 0, 0);
 			SET @ii = @ii + 1;
 		END
 		WHILE @jj <= @nOfSecondPeak
 		BEGIN
 			INSERT @array(i, j, [value])
 			VALUES(0,@jj,0);
 			SET @jj = @jj + 1;
 		END

 		SET @ii = 1;
 		SET @jj = 1;

 		WHILE @ii <= @nOfFirstPeak
 		BEGIN
 			SELECT @iv = cc.peak from (
				SELECT ROW_NUMBER() OVER (order by c.when_climbed) AS ROWNUM, c.peak, c.when_climbed
				FROM(
					SELECT DISTINCT climbed.peak, climbed.when_climbed
						from participated, climbed
						where participated.trip_id = climbed.trip_id AND participated.name = @firstN
				) as c) as cc
				where cc.ROWNUM = @ii
			WHILE @jj <= @nOfSecondPeak
			BEGIN
				SELECT @lv = cc.peak from (
				SELECT ROW_NUMBER() OVER (order by c.when_climbed) AS ROWNUM, c.peak, c.when_climbed
				FROM(
					SELECT DISTINCT climbed.peak, climbed.when_climbed
						from participated, climbed
						where participated.trip_id = climbed.trip_id AND participated.name = @secondN
				) as c) as cc
				where cc.ROWNUM = @jj

				IF @iv = @lv
				BEGIN
					SELECT @nextV = value +1
						FROM @array a WHERE a.i = @ii -1 AND a.j = @jj -1
				END	
				ELSE
				BEGIN
					SELECT @tmp1 = value
						FROM @array a WHERE a.i = @ii -1 AND a.j = @jj
					SELECT @tmp2 = value
						FROM @array a WHERE a.i = @ii AND a.j = @jj -1
					IF @tmp1 >= @tmp2 SELECT @nextV = @tmp1
					ELSE SELECT @nextV = @tmp2
				END
				INSERT @array(i,j,[value])
				VALUES(@ii,@jj,@nextV);
				SET @jj = @jj + 1;
			END
			SET @ii = @ii +1;
			SET @jj = 1;
 		END
 		SELECT @nextV = value
 		FROM @array a WHERE a.i = @nOfFirstPeak AND a.j = @nOfSecondPeak
 		DELETE FROM @array

		INSERT @LCSOfEachPerson(mName, yName, [value])
			VALUES(@firstN, @secondN, @nextV)
		SET @j = @j + 1
	END
	SELECT @tmp = max(l.value)
		FROM @LCSOfEachPerson l 
	SELECT @firstN = mName
		FROM @LCSOfEachPerson l WHERE l.value = @tmp
	SELECT @secondN = yName
		FROM @LCSOfEachPerson l WHERE l.value = @tmp
	INSERT @BestfEachPerson(mName, yName, [value])
		VALUES(@firstN, @secondN, @tmp)
	DELETE FROM @LCSOfEachPerson
	SET @i = @i +1
END

SELECT @firstN = bb.mName FROM(
SELECT * 
FROM @BestfEachPerson AS b 
WHERE b.value >= ALL(
SELECT value
FROM @BestfEachPerson
)) AS bb

SELECT @secondN = bb.yName FROM(
SELECT * 
FROM @BestfEachPerson AS b 
WHERE b.value >= ALL(
SELECT value
FROM @BestfEachPerson
)) AS bb

SELECT @nOfFirstPeak = COUNT(*)
	FROM participated AS p, climbed AS c
	WHERE p.name = @firstN AND p.trip_id = c.trip_id

SELECT @nOfSecondPeak = COUNT(*)
	FROM participated AS p, climbed AS c
	WHERE p.name = @secondN AND p.trip_id = c.trip_id

SET @ii = 0;
SET @jj = 0;

DELETE FROM @array

WHILE @ii <= @nOfFirstPeak
BEGIN
	INSERT @array(i, j, [value])
	VALUES(@ii, 0, 0);
	SET @ii = @ii + 1;
END
WHILE @jj <= @nOfSecondPeak
BEGIN
	INSERT @array(i, j, [value])
	VALUES(0,@jj,0);
	SET @jj = @jj + 1;
END

SET @ii = 1;
SET @jj = 1;

WHILE @ii <= @nOfFirstPeak
BEGIN
	SELECT @iv = cc.peak from (
	SELECT ROW_NUMBER() OVER (order by c.when_climbed) AS ROWNUM, c.peak, c.when_climbed
	FROM(
		SELECT DISTINCT climbed.peak, climbed.when_climbed
			from participated, climbed
			where participated.trip_id = climbed.trip_id AND participated.name = @firstN
	) as c) as cc
	where cc.ROWNUM = @ii
	WHILE @jj <= @nOfSecondPeak
	BEGIN
		SELECT @lv = cc.peak from (
		SELECT ROW_NUMBER() OVER (order by c.when_climbed) AS ROWNUM, c.peak, c.when_climbed
		FROM(
			SELECT DISTINCT climbed.peak, climbed.when_climbed
				from participated, climbed
				where participated.trip_id = climbed.trip_id AND participated.name = @secondN
		) as c) as cc
		where cc.ROWNUM = @jj

		IF @iv = @lv
		BEGIN
			SELECT @nextV = value +1
				FROM @array a WHERE a.i = @ii -1 AND a.j = @jj -1
		END	
		ELSE
		BEGIN
			SELECT @tmp1 = value
				FROM @array a WHERE a.i = @ii -1 AND a.j = @jj
			SELECT @tmp2 = value
				FROM @array a WHERE a.i = @ii AND a.j = @jj -1
			IF @tmp1 >= @tmp2 SELECT @nextV = @tmp1
			ELSE SELECT @nextV = @tmp2
		END
		INSERT @array(i,j,[value])
		VALUES(@ii,@jj,@nextV);
		SET @jj = @jj + 1;
	END
	SET @ii = @ii +1;
	SET @jj = 1;
END

SELECT @tmp = value
FROM @array a WHERE a.i = @nOfFirstPeak AND a.j = @nOfSecondPeak

DECLARE @lcslist table(n int,peak VARCHAR(30));

SET @ii = @nOfFirstPeak;
SET @jj = @nOfSecondPeak;

WHILE (@ii > 0 AND @jj > 0)
BEGIN
	SELECT @iv = cc.peak from (
	SELECT ROW_NUMBER() OVER (order by c.when_climbed) AS ROWNUM, c.peak, c.when_climbed
	FROM(
		SELECT DISTINCT climbed.peak, climbed.when_climbed
			from participated, climbed
			where participated.trip_id = climbed.trip_id AND participated.name = @firstN
	) as c) as cc
	where cc.ROWNUM = @ii

	SELECT @lv = cc.peak from (
	SELECT ROW_NUMBER() OVER (order by c.when_climbed) AS ROWNUM, c.peak, c.when_climbed
	FROM(
		SELECT DISTINCT climbed.peak, climbed.when_climbed
			from participated, climbed
			where participated.trip_id = climbed.trip_id AND participated.name = @secondN
	) as c) as cc
	where cc.ROWNUM = @jj

	IF (@iv = @lv) 
	BEGIN
		INSERT @lcslist(n, peak)
		VALUES (@tmp, @iv)
		SET @tmp = @tmp -1;
		SET @ii = @ii -1;
		SET @jj = @jj -1;
	END
	ELSE
	BEGIN
		SELECT @tmp1 = value 
		FROM @array a
		WHERE a.i = @ii AND a.j = @jj -1
		SELECT @tmp2 = value 
		FROM @array a
		WHERE a.i = @ii-1 AND a.j = @jj 
		IF @tmp1 >= @tmp2 SET @jj = @jj -1
		ELSE SET @ii = @ii - 1
	END
END

PRINT 'The two most similar climbers are ' + @firstN + ' and ' + @secondN+'.'
PRINT ' '
PRINT 'The longest sequence of peak ascents common to both is:'

SELECT peak AS ' ' FROM @lcslist ORDER BY n 

END
GO

