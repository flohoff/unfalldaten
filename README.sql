Um für einen Ort die Geometrieen der Straßen und ihre Geschwindigkeitsbeschränkungen
zu bekommen ist eine postgres/postgis mit einem osm extrakt nötig der via "osm2pgsql" 
importiert wird:

Auf einem Debian Jessie (Evtl gehen auch aktuelle Ubuntu versionen)

- Datenbank installieren und vorbereiten:

	sudo apt-get install postgresql-9.4 postgis osm2pgsql
	sudo --user=postgres createuser --superuser --no-createdb --no-createrole `whoami`
	sudo --user=postgres createdb --encoding=UTF8 --owner=`whoami` osm
	psql --dbname=osm --command="CREATE EXTENSION postgis"
	psql --dbname=osm --command="CREATE EXTENSION hstore"

- OSM Extrakt besorgen - hier - Regierungsbezirk Detmold:

	wget http://download.geofabrik.de/europe/germany/nordrhein-westfalen/detmold-regbez-latest.osm.pbf

- OSM Extrakt in die GIS Datenbank importieren:

	osm2pgsql --hstore --create --latlong --slim \
		--cache 2000 -d osm -U `whoami` detmold-regbez-latest.osm.pbf

  Je nach Extraktgröße und Rechner dauert der import von wenigen Minuten bis zu Stunden/Tage.
  Regierungsbezirk Detmold auf einem Lenovo T420 Notebook mit 8GByte Ram und SSD dauert 12 Minuten

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

	psql osm -f boundaryfilewithextension.sql

- Dann alle straßen mit Geschwindigkeitsbeschränkungen exportieren:

	psql osm

	-- Output file setzen
	\o outputfile
	-- Output format - table "garnitur" abschalten
	\t on
	-- Statement auf die command line vom psql pasten
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

