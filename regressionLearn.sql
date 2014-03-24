CREATE PROCEDURE regressionLearn
@regularizationParam float,
@stoppingCriteria float,
@learningRate float
AS BEGIN
DECLARE @numOfDim INT
DECLARE @numOfPoints INT
DECLARE @tmp FLOAT
DECLARE @i INT, @j int
DECLARE @r table (num int, value float);
DECLARE @tmpr float, @tmpx float, @tmpy int, @tmpPID int
DECLARE @l float, @l1 float

SET @i = 1

SELECT @numOfDim = MAX(dim) FROM data;
SELECT @numOfPoints = COUNT(*) FROM datapoints;

WHILE @i <= @numOfDim
BEGIN
	SELECT @tmp = SUM(value) FROM data WHERE dim = @i
	IF @tmp <> 0
	BEGIN
		UPDATE data
		SET value = value - @tmp/@numOfPoints
		WHERE dim = @i;
	END
	SET @i = @i +1
END
SET @i = 1;
WHILE @i <= @numOfDim
BEGIN 
	SELECT @tmp = SUM(value*value) FROM data WHERE dim = @i;
	IF @tmp <> @numOfPoints
	BEGIN
		UPDATE data
		SET value = value/SQRT(@tmp/@numOfPoints)
		WHERE dim = @i;
	END
	SET @i = @i +1;
END
IF EXISTS(SELECT * FROM information_schema.tables WHERE table_name = 'coefs')
DROP table coefs;
CREATE TABLE coefs
(
	dim int,
	value float
);

SET @i = 1
WHILE @i <= @numOfDim
BEGIN
	INSERT @r(num, value) VALUES(@i, 0);
	INSERT coefs(dim, value) VALUES(@i, 0);
	SET @i = @i + 1;
END


select @l = sum(power(xr.value - datapoints.classLabel,2))
FROM(
select sum(a.value) as value, a. pointid
from(
select tmp.value * coefs.value as value, tmp.pointid
from (
select data.value, data.pointid,data.dim
FROM data, datapoints
WHERE data.pointid = datapoints.pointid AND datapoints.istraining = 1) as tmp 
inner join coefs
on tmp.dim = coefs.dim) as a
group by a.pointid) as xr,datapoints
WHERE xr.pointid = datapoints.pointid


SELECT @tmp = SUM(value*value) FROM coefs
SET @l = @l + @regularizationParam * @tmp;
SET @l1 = @l

print cast(@l AS varchar(30));
-- initial loss value done
DECLARE @count int, @k int
DECLARE @rr table (dim int, value float);
SET @count = 1
SET @k = 1

WHILE @count >= 1
BEGIN
	print ' '
	print 'iteration:' + cast(@count as varchar(30))
	DELETE FROM @rr;
	WHILE @k <= @numOfDim
	BEGIN
		select @tmpr = sum((xr.value - datapoints.classLabel)*data.value)
		from(
		select sum(a.value) as value, a. pointid
		from(
		select tmp.value * coefs.value as value, tmp.pointid
		from (
		select data.value, data.pointid,data.dim,datapoints.classLabel
		FROM data, datapoints
		WHERE data.pointid = datapoints.pointid AND datapoints.istraining = 1) as tmp 
		inner join coefs
		on tmp.dim = coefs.dim) as a
		group by a.pointid) as xr, datapoints, data
		where xr.pointid = datapoints.pointid AND data.pointid = xr.pointid AND data.dim = @k

		SELECT @tmp = value FROM coefs WHERE dim = @k
		SET @tmpr = @tmpr + @regularizationParam * @tmp

		INSERT @rr(dim, value) VALUES(@k, @tmp - @learningRate*@tmpr); 

		SET @k = @k + 1
	END

	select @l = sum(power(xr.value - datapoints.classLabel,2))
	FROM(
	select sum(a.value) as value, a. pointid
	from(
	select tmp.value * r.value as value, tmp.pointid
	from (
	select data.value, data.pointid,data.dim
	FROM data, datapoints
	WHERE data.pointid = datapoints.pointid AND datapoints.istraining = 1) as tmp 
	inner join @rr r
	on tmp.dim = r.dim) as a
	group by a.pointid) as xr,datapoints
	WHERE xr.pointid = datapoints.pointid

	SELECT @tmp = SUM(value*value) FROM @rr
	SET @l = @l + @regularizationParam * @tmp;
	print 'l:' + cast(@l as varchar(30))
	print 'l1:' + cast(@l1 as varchar(30))


	print cast((@l1 - @l)/@l1 as varchar(30))
	IF ((@l1 - @l)/@l1 >= @stoppingCriteria)
	BEGIN
		SET @i = 1
		WHILE @i <= @numOfDim
		BEGIN
			SELECT @tmp = value
			FROM @rr WHERE dim = @i
			
			UPDATE coefs
			SET value = @tmp
			WHERE dim = @i

			SET @i = @i +1
		END
		SET @l1 =  @l
		print cast(@l1 as varchar(30))
	END
	ELSE BREAK

	SET @count = @count + 1
	SET @k = 1
END
END
GO