<?php
/**
 * Builds assets/seed/en.json and assets/seed/ur.json from the sample content
 * that ships with the sh-stories, sh-museums, sh-cities and sh-castles plugins.
 *
 * The app shows this built-in library on first launch when the phone is
 * offline or the website does not have the sh-app-api plugin yet. The JSON
 * has the same shape as GET /wp-json/sh-app/v1/bundle.
 *
 * Usage: php tool/build_seed.php <folder containing the four plugin folders> <output folder>
 */

define( 'ABSPATH', __DIR__ . '/' );

$src = rtrim( $argv[1] ?? '', '/' );
$out = rtrim( $argv[2] ?? __DIR__ . '/../assets/seed', '/' );
if ( ! is_dir( $src ) ) {
	fwrite( STDERR, "Usage: php build_seed.php <plugins folder> [output folder]\n" );
	exit( 1 );
}

function find_file( $src, $plugin, $file ) {
	foreach ( array( "$src/$plugin/$plugin/sample-content/$file", "$src/$plugin/sample-content/$file" ) as $path ) {
		if ( is_file( $path ) ) {
			return $path;
		}
	}
	fwrite( STDERR, "Missing $plugin/$file\n" );
	exit( 1 );
}

$next_id = 1000;
/** Same item in both languages: en id is even, ur id is odd. */
function ids() {
	global $next_id;
	$next_id += 2;
	return array(
		'en' => $next_id,
		'ur' => $next_id + 1,
	);
}

function html( $paragraphs ) {
	$out = '';
	foreach ( (array) $paragraphs as $p ) {
		$out .= '<p>' . htmlspecialchars( $p, ENT_NOQUOTES, 'UTF-8' ) . "</p>\n";
	}
	return trim( $out );
}

function minutes( $paragraphs, $lang ) {
	$words = preg_match_all( '/[\p{L}\p{N}]+/u', implode( ' ', (array) $paragraphs ) );
	return max( 1, (int) ceil( $words / ( 'ur' === $lang ? 150 : 200 ) ) );
}

function date_days_ago( $days ) {
	return gmdate( 'c', strtotime( '2026-10-10 09:00:00 UTC' ) - $days * 86400 );
}

$site   = 'https://somethinghistoric.com';
$bundle = array();
foreach ( array( 'en', 'ur' ) as $lang ) {
	$bundle[ $lang ] = array(
		'version'          => 'seed-1',
		'generated'        => gmdate( 'c' ),
		'lang'             => $lang,
		'site'             => array(
			'name' => 'Something Historic',
			'url'  => $site . '/',
		),
		'empires'          => array(),
		'series'           => array(),
		'episodes'         => array(),
		'posts'            => array(),
		'museums'          => array(),
		'museum_types'     => array(),
		'museum_countries' => array(),
		'cities'           => array(),
		'city_regions'     => array(),
		'castles'          => array(),
		'castle_regions'   => array(),
	);
}

function link_for( $lang, $path ) {
	global $site;
	return $site . ( 'ur' === $lang ? '/ur' : '' ) . '/' . trim( $path, '/' ) . '/';
}

/* ---------------------------------------------------------------- Stories */

$data    = require find_file( $src, 'sh-stories', 'data.php' );
$more    = require find_file( $src, 'sh-stories', 'data-more.php' );
$library = require find_file( $src, 'sh-stories', 'data-library.php' );

$data = array_merge( $data, $library['empires'] );
foreach ( $more['series'] as $key => $series ) {
	if ( ! empty( $library['append'][ $series['en']['slug'] ] ) ) {
		$more['series'][ $key ]['episodes'] = array_merge( $series['episodes'], $library['append'][ $series['en']['slug'] ] );
	}
}
$more['posts'] = array_merge( $more['posts'], $library['posts'] );

$empire_style = array();

$add_series = function ( $series, $empire_ids, $empire, $offset ) use ( &$bundle ) {
	$sid       = ids();
	$published = array_values(
		array_filter(
			$series['episodes'],
			function ( $e ) {
				return empty( $e['scheduled'] );
			}
		)
	);
	foreach ( array( 'en', 'ur' ) as $lang ) {
		$bundle[ $lang ]['series'][] = array(
			'id'           => $sid[ $lang ],
			'slug'         => $series[ $lang ]['slug'],
			'name'         => $series[ $lang ]['name'],
			'description'  => '',
			'parent'       => 0,
			'count'        => count( $published ),
			'link'         => link_for( $lang, 'series/' . $series[ $lang ]['slug'] ),
			'translations' => $sid,
			'empire'       => $empire_ids[ $lang ],
			'intro'        => $series[ $lang ]['intro'],
			'image'        => '',
			'total'        => (int) $series['total'],
			'status'       => $series['status'],
			'palette'      => $empire['palette'],
			'shape'        => $empire['shape'],
		);
	}
	foreach ( $published as $index => $episode ) {
		$eid    = ids();
		$number = $index + 1;
		$date   = date_days_ago( $offset + 7 * ( count( $published ) - $number ) );
		foreach ( array( 'en', 'ur' ) as $lang ) {
			$e                             = $episode[ $lang ];
			$bundle[ $lang ]['episodes'][] = array(
				'id'              => $eid[ $lang ],
				'slug'            => $e['slug'],
				'title'           => $e['title'],
				'excerpt'         => $e['excerpt'],
				'content'         => html( $e['content'] ),
				'date'            => $date,
				'modified'        => $date,
				'image'           => '',
				'link'            => link_for( $lang, 'stories/' . $e['slug'] ),
				'translations'    => $eid,
				'series'          => $sid[ $lang ],
				'empire'          => $empire_ids[ $lang ],
				'number'          => $number,
				'next_release'    => '',
				'reading_minutes' => minutes( $e['content'], $lang ),
				'palette'         => $empire['palette'],
				'shape'           => $empire['shape'],
			);
		}
	}
};

foreach ( $data as $empire_index => $empire ) {
	$key  = $empire['key'];
	$eids = ids();
	foreach ( array( 'en', 'ur' ) as $lang ) {
		$bundle[ $lang ]['empires'][] = array(
			'id'           => $eids[ $lang ],
			'slug'         => $empire[ $lang ]['slug'],
			'name'         => $empire[ $lang ]['name'],
			'description'  => '',
			'parent'       => 0,
			'count'        => 0,
			'link'         => link_for( $lang, 'empire/' . $empire[ $lang ]['slug'] ),
			'translations' => $eids,
			'period'       => $empire[ $lang ]['period'],
			'intro'        => $empire[ $lang ]['intro'],
			'image'        => '',
			'map'          => '',
			'palette'      => $empire['palette'],
			'shape'        => $empire['shape'],
		);
	}
	$empire_style[ $key ] = array( $empire['palette'], $empire['shape'], $eids );

	$series = $empire['series'];
	if ( ! empty( $more['episodes'][ $key ] ) ) {
		$series['episodes'] = array_merge( $series['episodes'], $more['episodes'][ $key ] );
	}
	$add_series( $series, $eids, $empire, 3 + $empire_index * 2 );
	if ( ! empty( $more['series'][ $key ] ) ) {
		$add_series( $more['series'][ $key ], $eids, $empire, 1 + $empire_index );
	}
	if ( ! empty( $library['series'][ $key ] ) ) {
		foreach ( $library['series'][ $key ] as $extra_index => $extra ) {
			$add_series( $extra, $eids, $empire, 2 + $empire_index + 3 * $extra_index );
		}
	}
}

// Empire episode counts.
foreach ( array( 'en', 'ur' ) as $lang ) {
	$counts = array_count_values( array_column( $bundle[ $lang ]['episodes'], 'empire' ) );
	foreach ( $bundle[ $lang ]['empires'] as &$e ) {
		$e['count'] = $counts[ $e['id'] ] ?? 0;
	}
	unset( $e );
}

foreach ( $more['posts'] as $index => $post ) {
	$pid   = ids();
	$date  = date_days_ago( 2 + 3 * $index );
	$style = $empire_style[ $post['image'] ] ?? array( array( '#2a1408', '#a0522d', '#f2c27b' ), 'dome' );
	foreach ( array( 'en', 'ur' ) as $lang ) {
		$p                          = $post[ $lang ];
		$bundle[ $lang ]['posts'][] = array(
			'id'              => $pid[ $lang ],
			'slug'            => $p['slug'],
			'title'           => $p['title'],
			'excerpt'         => $p['excerpt'],
			'content'         => html( $p['content'] ),
			'date'            => $date,
			'modified'        => $date,
			'image'           => '',
			'link'            => link_for( $lang, $p['slug'] ),
			'translations'    => $pid,
			'categories'      => array( $more['category'][ $lang ]['name'] ),
			'reading_minutes' => minutes( $p['content'], $lang ),
			'palette'         => $style[0],
			'shape'           => $style[1],
		);
	}
}

/* ---------------------------------------------------------------- Museums */

$terms     = require find_file( $src, 'sh-museums', 'data-terms.php' );
$term_ids  = array();
foreach ( array( 'museum_type' => 'museum_types', 'museum_country' => 'museum_countries' ) as $tax => $field ) {
	foreach ( $terms[ $tax ] as $slug => $t ) {
		$tid                     = ids();
		$term_ids[ $tax ][ $slug ] = $tid;
		foreach ( array( 'en', 'ur' ) as $i => $lang ) {
			$bundle[ $lang ][ $field ][] = array(
				'id'           => $tid[ $lang ],
				'slug'         => 'ur' === $lang ? $slug . '-ur' : $slug,
				'name'         => $t[ $i ],
				'description'  => $t[ $i + 2 ] ?? '',
				'parent'       => 0,
				'count'        => 0,
				'link'         => link_for( $lang, str_replace( '_', '-', $tax ) . '/' . $slug ),
				'translations' => $tid,
			);
		}
	}
}

$museums = array_merge(
	require find_file( $src, 'sh-museums', 'data-pakistan.php' ),
	require find_file( $src, 'sh-museums', 'data-world.php' )
);
$empire_by_key = array();
foreach ( $empire_style as $key => $style ) {
	$empire_by_key[ $key ] = $style[2];
}
foreach ( $museums as $index => $museum ) {
	$mid  = ids();
	$date = date_days_ago( 1 + $index );
	foreach ( array( 'en', 'ur' ) as $lang ) {
		$m                            = $museum[ $lang ];
		$bundle[ $lang ]['museums'][] = array(
			'id'           => $mid[ $lang ],
			'slug'         => $museum['key'] . ( 'ur' === $lang ? '-ur' : '' ),
			'title'        => $m['title'],
			'excerpt'      => $m['tagline'],
			'content'      => html( $m['intro'] ),
			'date'         => $date,
			'modified'     => $date,
			'image'        => '',
			'link'         => link_for( $lang, 'museums/' . $museum['key'] ),
			'translations' => $mid,
			'type'         => isset( $term_ids['museum_type'][ $museum['type'] ] ) ? array( $term_ids['museum_type'][ $museum['type'] ][ $lang ] ) : array(),
			'country'      => isset( $term_ids['museum_country'][ $museum['country'] ] ) ? array( $term_ids['museum_country'][ $museum['country'] ][ $lang ] ) : array(),
			'meta'         => array(
				'tagline'    => $m['tagline'],
				'city'       => $m['city'],
				'address'    => $m['address'],
				'founded'    => (string) $museum['founded'],
				'hours'      => $m['hours'],
				'tickets'    => $m['tickets'],
				'website'    => (string) $museum['website'],
				'lat'        => (string) $museum['lat'],
				'lng'        => (string) $museum['lng'],
				'highlights' => array_values( $m['highlights'] ),
				'featured'   => (bool) $museum['featured'],
				'empires'    => array_values(
					array_filter(
						array_map(
							function ( $k ) use ( $empire_by_key, $lang ) {
								return $empire_by_key[ $k ][ $lang ] ?? 0;
							},
							(array) $museum['empires']
						)
					)
				),
			),
			'palette'      => $museum['palette'],
			'shape'        => $museum['shape'],
		);
	}
}

/* ------------------------------------------------------- Cities, castles */

$places = array(
	array( 'sh-cities', array( 'data-cities-1.php', 'data-cities-2.php' ), 'cities', 'city_regions', 'ancient-cities', 'city-region', array( 'tagline', 'location', 'founded', 'civilization' ) ),
	array( 'sh-castles', array( 'data-castles-1.php', 'data-castles-2.php' ), 'castles', 'castle_regions', 'castles', 'castle-region', array( 'tagline', 'location', 'built', 'builder' ) ),
);
foreach ( $places as $place ) {
	list( $plugin, $files, $field, $region_field, $base, $region_base, $text_keys ) = $place;
	$regions    = require find_file( $src, $plugin, 'data-regions.php' );
	$region_ids = array();
	foreach ( $regions as $region ) {
		$rid                          = ids();
		$region_ids[ $region['key'] ] = $rid;
		foreach ( array( 'en', 'ur' ) as $lang ) {
			$bundle[ $lang ][ $region_field ][] = array(
				'id'           => $rid[ $lang ],
				'slug'         => $region['key'] . ( 'ur' === $lang ? '-ur' : '' ),
				'name'         => $region[ $lang ]['name'],
				'description'  => $region[ $lang ]['description'],
				'parent'       => 0,
				'count'        => 0,
				'link'         => link_for( $lang, $region_base . '/' . $region['key'] ),
				'translations' => $rid,
				'image'        => '',
			);
		}
	}
	$items = array();
	foreach ( $files as $file ) {
		$items = array_merge( $items, require find_file( $src, $plugin, $file ) );
	}
	foreach ( $items as $index => $item ) {
		$iid  = ids();
		$date = date_days_ago( 1 + $index );
		foreach ( array( 'en', 'ur' ) as $lang ) {
			$x    = $item[ $lang ];
			$meta = array();
			foreach ( $text_keys as $k ) {
				$meta[ $k ] = (string) ( $x[ $k ] ?? '' );
			}
			$meta = array_merge(
				$meta,
				array(
					'type'       => (string) ( $item['type'] ?? '' ),
					'year'       => (string) ( $item['year'] ?? '' ),
					'status'     => (string) ( $item['status'] ?? '' ),
					'unesco'     => (string) ( $item['unesco'] ?? '' ),
					'lat'        => (string) ( $item['lat'] ?? '' ),
					'lng'        => (string) ( $item['lng'] ?? '' ),
					'highlights' => array_values( (array) ( $x['highlights'] ?? array() ) ),
					'timeline'   => array_values( (array) ( $x['timeline'] ?? array() ) ),
					'featured'   => ! empty( $item['featured'] ),
				)
			);
			$bundle[ $lang ][ $field ][] = array(
				'id'           => $iid[ $lang ],
				'slug'         => $item['key'] . ( 'ur' === $lang ? '-ur' : '' ),
				'title'        => $x['title'],
				'excerpt'      => $x['excerpt'] ?? $x['tagline'],
				'content'      => html( $x['content'] ),
				'date'         => $date,
				'modified'     => $date,
				'image'        => '',
				'link'         => link_for( $lang, $base . '/' . $item['key'] ),
				'translations' => $iid,
				'region'       => isset( $region_ids[ $item['region'] ] ) ? array( $region_ids[ $item['region'] ][ $lang ] ) : array(),
				'meta'         => $meta,
				'palette'      => $item['palette'],
				'shape'        => $item['shape'],
			);
		}
	}
}

if ( ! is_dir( $out ) ) {
	mkdir( $out, 0777, true );
}
foreach ( $bundle as $lang => $b ) {
	file_put_contents( "$out/$lang.json", json_encode( $b, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) );
	printf(
		"%s: %d empires, %d series, %d episodes, %d posts, %d museums, %d cities, %d castles\n",
		$lang,
		count( $b['empires'] ),
		count( $b['series'] ),
		count( $b['episodes'] ),
		count( $b['posts'] ),
		count( $b['museums'] ),
		count( $b['cities'] ),
		count( $b['castles'] )
	);
}
