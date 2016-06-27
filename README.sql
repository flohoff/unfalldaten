Um für einen Ort die Geometrieen der Straßen und ihre Geschwindigkeitsbeschränkungen
zu bekommen ist eine postgres/postgis mit einem osm extrakt nötig der via "osm2pgsql" 
importiert wird:

	TODO - Beschreibung wie man die hinbekommt.


Um die geojson Boundary in die SQL Datenbank zu bekommen 

- Vor dem geojson einfügen:
	drop table t2;
	WITH data AS (SELECT '

- Hinter dem geojson einfügen

	'::json AS fc)

	SELECT
	  row_number() OVER () AS gid,
	  ST_SetSRID(ST_GeomFromGeoJSON(feat->>'geometry'),4326) AS geom,
	  feat->'properties' AS properties
	into t2
	FROM (
		  SELECT json_array_elements(fc->'features') AS feat
		  FROM data
	) AS f;

- Dann ausführen - Danach ist die geometrie in der tabelle t2

- Dann alle straßen mit Geschwindigkeitsbeschränkungen exportieren:

	select	row_to_json(featurecollection)
	from	(
		select	'FeatureCollection' as type,
			array_to_json(array_agg(features)) as features
		from	(
			 select	'Feature' as type,
				ST_AsGeoJSON(way)::json as geometry,
				json_build_object('maxspeed', maxspeed, 'highway', highway) as properties
			from	(
				select	way,
					tags -> 'maxspeed' maxspeed,
					highway
				from	planet_osm_line r, t2 b
				where	r.way && b.geom
				and	highway is not null
				and	( tags ? 'maxspeed' or highway in ( 'pedestrian', 'living_street' ) )
				and	ST_Intersects(r.way, b.geom)
				) ways
			) features
		) featurecollection;

