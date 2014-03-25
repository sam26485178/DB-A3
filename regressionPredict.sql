CREATE PROCEDURE regressionPredict
AS BEGIN
	DECLARE @result table(pointid int, value int)

	DECLARE myResult CURSOR FOR

	select sum(a.value) as value, a.pointid
	from(
	SELECT tmp.value*coefs.value as value , tmp.pointid
	from(
	SELECT data.value, data.pointid, data.dim, datapoints.classLabel
	FROM data, datapoints
	WHERE data.pointid = datapoints.pointid AND datapoints.istraining = -1) as tmp
	inner join coefs
	on tmp.dim = coefs.dim) as a
	group by a.pointid

	DECLARE @predictValue float, @pointid int
	OPEN myResult

	FETCH FROM myResult INTO @predictValue, @pointid

	WHILE(@@FETCH_STATUS = 0)
	BEGIN
		IF @predictValue >=0
		BEGIN
			INSERT @result(pointid, value) VALUES(@pointid, 1)
		END
		ELSE
		BEGIN
			INSERT @result(pointid, value) VALUES(@pointid, -1)
		END
		FETCH FROM myResult INTO @predictValue, @pointid
	END
	CLOSE myResult
	DEALLOCATE myResult
	
	DECLARE @tmp int, @numOfFP float, @numOfFN float, @numOfcorrect float, @numOfCancer float, @numOfNotCancer float
	DECLARE @rateOfFP float, @rateOFFN float
	
	SELECT @numOfcorrect = COUNT(*)
	FROM @result r, datapoints d
	WHERE (r.pointid = d.pointid) AND ((r.value = 1 AND d.classLabel = 1) OR (r.value = -1 AND d.classLabel = -1))

	SELECT @tmp = COUNT(*) FROM @result r

	SELECT @numOfCancer = COUNT(*)
	FROM @result r
	WHERE r.value = 1

	SELECT @numOfNotCancer = COUNT(*)
	FROM @result r
	WHERE r.value = -1

	SELECT @numOfFP = COUNT(*)
	FROM @result r, datapoints d
	WHERE r.pointid = d.pointid AND r.value = 1 AND d.classLabel = -1

	SELECT @numOfFN = COUNT(*)
	FROM @result r, datapoints d 
	WHERE r.pointid = d.pointid AND r.value = -1 AND d.classLabel = 1

	SET @rateOfFP = @numOfFP/@numOfCancer
	SET @rateOFFN = @numOfFN/@numOfNotCancer

	print cast(@numOfcorrect as varchar(11)) + ' out of ' + cast(@tmp as varchar(11))
			+' test points were labeled correctly.  '
	print 'False positive rate was ' + cast(@rateOfFP*100 as varchar(11)) +'% and false negative rate was ' +
			 cast(@rateOFFN*100 as varchar(11)) +'%.'
END
GO