--1 1871-2016
SELECT MIN (yearid), MAX(yearid)
FROM teams

--2
SELECT CONCAT(namefirst,' ', namelast) AS full_name, MIN(height) AS height_inches, g_all AS number_games_played, name AS team_name
FROM people INNER JOIN appearances USING(playerid) 
			INNER JOIN teams USING (teamid)
GROUP BY playerid, g_all, teamid, name
ORDER BY height
LIMIT 1;


--3 David Price earned the most money in the majors of Vanderbilt players.
WITH vandy_players AS (SELECT playerid, namefirst, namelast
	FROM people INNER JOIN collegeplaying USING(playerid) 
				INNER JOIN schools USING(schoolid) 
	WHERE schoolname ILIKE '%Vanderbilt%'
	GROUP BY playerid, namefirst, namelast)

SELECT vandy_players.*, SUM(salary)::numeric::money AS total_salary
	FROM vandy_players LEFT JOIN salaries USING (playerid)
GROUP BY playerid, namefirst, namelast
ORDER BY total_salary DESC NULLS LAST;	


--4 
SELECT 
	CASE WHEN pos='OF' THEN 'Outfield'
	WHEN pos IN('SS','1B','2B','3B') THEN 'Infield'
	WHEN pos IN('P','C') THEN 'Battery' END AS field_pos,
	SUM(po) AS putout_sum_2016
FROM fielding
WHERE yearid=2016
GROUP BY field_pos;


--5 Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends?
--Strikeouts have increased through the decades, and home runs have as well but only slightly.

SELECT ((yearid)/10)*10 AS Decade, ROUND(SUM(so)/(SUM(g)::numeric/2),2) AS avg_so_game, ROUND(SUM(hr)/(SUM(g)::numeric/2),2) AS avg_hr_game
FROM teams
WHERE yearid>=1920
GROUP BY Decade
ORDER BY Decade;


--6 Chris Owings had the most success stealing bases in 2016.
WITH total_sb_attempts AS (SELECT playerid, SUM(sb)::numeric AS total_sb,(SUM(SB)+SUM(CS))::numeric AS sb_attempts
	FROM batting
	WHERE yearid=2016
	GROUP BY playerid
	HAVING (SUM(SB)+SUM(CS))>=20) 

SELECT playerid, namefirst, namelast, ROUND((total_sb/sb_attempts)*100, 2) AS success_rate
FROM total_sb_attempts INNER JOIN people USING (playerid)
GROUP BY playerid, namefirst, namelast, success_rate
ORDER BY success_rate DESC
LIMIT 1;


--7 From 1970 – 2016: 
--NO WS in 1994 and only 111 of 162 games were played in the 1981 WS.
--Team with largest # of wins that DID NOT win WS, and team with smallest # of wins that won WS.
(SELECT teamid, yearid, MAX(w) AS total_wins, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND wswin='N'AND yearid<>1994 		AND yearid<>1981
GROUP BY teamid, yearid, wswin
ORDER BY total_wins DESC
LIMIT 1)
UNION
(SELECT teamid, yearid, MIN(w)AS total_wins, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND wswin='Y'AND yearid<>1994 		AND yearid<>1981
GROUP BY teamid, yearid, wswin
ORDER BY total_wins
LIMIT 1);

--Teams with the most wins that year that also won the WS; 12 teams in 45 years. 
(SELECT teamid, yearid, w, wswin, MAX(w)OVER(PARTITION BY yearid)AS max_year
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND yearid<>1994 AND 				yearid<>1981
GROUP BY teamid, yearid, w, wswin
ORDER BY yearid)
INTERSECT
(SELECT teamid, yearid, w, wswin, MAX(w)OVER(PARTITION BY yearid)AS max_year
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND yearid<>1994 AND yearid<> 		1981 AND wswin='Y'
GROUP BY teamid, yearid, w, wswin
ORDER BY yearid)
ORDER BY yearid;

--Count of above
SELECT COUNT(*)
FROM ((SELECT teamid, yearid, w, wswin, MAX(w)OVER(PARTITION BY yearid)AS max_year
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND yearid<>1994 AND 				yearid<>1981
GROUP BY teamid, yearid, w, wswin
ORDER BY yearid)
INTERSECT
(SELECT teamid, yearid, w, wswin, MAX(w)OVER(PARTITION BY yearid)AS max_year
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND yearid<>1994 AND yearid<> 		1981 AND wswin='Y'
GROUP BY teamid, yearid, w, wswin
ORDER BY yearid)
ORDER BY yearid);

--Percentage of when WS winners also have the most wins per year
WITH max_winners AS ((SELECT teamid, yearid, w::numeric, wswin, 					MAX(w)OVER(PARTITION BY 											yearid)::numeric AS max_year
		FROM teams
		WHERE yearid BETWEEN 1970 AND 2016 AND yearid<>1994 AND 				yearid<>1981
		GROUP BY teamid, yearid, w, wswin
		ORDER BY yearid)
		INTERSECT
		(SELECT teamid, yearid, w::numeric, wswin, 							MAX(w)OVER(PARTITION BY yearid)::numeric AS max_year
		FROM teams
		WHERE yearid BETWEEN 1970 AND 2016 AND yearid<>1994 AND 				yearid<> 1981 AND wswin='Y'
		GROUP BY teamid, yearid, w, wswin
		ORDER BY yearid)),
	
total_wins AS (SELECT teamid, yearid, MIN(w)::numeric AS 							total_wins, wswin
				FROM teams
			WHERE yearid BETWEEN 1970 AND 2016 AND wswin='Y'AND 					yearid<>1994 AND yearid<>1981
		GROUP BY teamid, yearid, wswin
		ORDER BY total_wins)
	
SELECT ROUND(100*(SELECT COUNT(yearid)::numeric AS max
	FROM max_winners)/(SELECT COUNT(yearid)::numeric AS total FROM 	total_wins),2) AS percentage_wswinner_with_maxwins;


--12 In this question, you will explore the connection between number of wins and attendance.

--12a: There is not a significant correlation between home game attendance and number of wins.
WITH win_attend AS (SELECT team, year, w, 											SUM(homegames.attendance)AS hg_attendance
			FROM homegames LEFT JOIN teams ON 										homegames.team=teams.teamid AND 									homegames.year=teams.yearid 
			GROUP BY year, team, w
			ORDER BY year, team, w, hg_attendance)

SELECT ROUND(CORR(w,hg_attendance)::numeric,2) AS win_attendance_correlation
FROM win_attend

	
--13 It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. 
	
--While it is true that left handed pitchers are more rare overll than right handed pitchers, it cannont be said that one is more effective over the other based upon the percentage of each who won the Cy Young Award and the perecentage of each inducted into the Hall of Fame. However, if effectiveness is based only upon the percentage of each winning the Cy Young award, then yes, left handed pitchers would be more effective.
	
SELECT COUNT(throws)AS r_throws
FROM people
WHERE throws='R'; 

SELECT COUNT(throws) AS l_throws
FROM people
WHERE throws='L'; 

--Percentag left handers over right
SELECT ROUND(100*(SELECT COUNT(throws)::numeric 
	      FROM people
          WHERE throws='L')/
			(SELECT COUNT(throws)::numeric
			FROM people
			WHERE throws='R'),2)::numeric
AS percent_left_over_right;

--Percetage left handers who receive Cy Young Award (1.01%)
SELECT ROUND((100*(SELECT COUNT(throws)::numeric
FROM awardsplayers LEFT JOIN people USING(playerid)
WHERE awardid='Cy Young Award' AND throws='L')/(SELECT 				COUNT(throws)::numeric FROM people WHERE 							throws='L')),2)::numeric;

--Percentage right handers who won Cy Young Award (0.52%)
SELECT ROUND((100*(SELECT COUNT(throws)::numeric
FROM awardsplayers LEFT JOIN people USING(playerid)
WHERE awardid='Cy Young Award' AND throws='R')/(SELECT 				COUNT(throws)::numeric FROM people WHERE 							throws='R')),2)::numeric;

--Percentage left handers who are in Hall of Fame (1.42%)
SELECT ROUND((100*(SELECT COUNT(playerid)::numeric
FROM halloffame LEFT JOIN people USING (playerid)
WHERE throws='L'AND inducted='Y')/(SELECT COUNT(playerid)::numeric 	FROM people WHERE throws='L'))::numeric,2);

--Percentage right handers in Hall of Fame (1.6%)
SELECT ROUND((100*(SELECT COUNT(playerid)::numeric
FROM halloffame LEFT JOIN people USING (playerid)
WHERE throws='R' AND inducted='Y')/(SELECT 							COUNT(playerid)::numeric FROM people WHERE 						throws='R'))::numeric,2);


