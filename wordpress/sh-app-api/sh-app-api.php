<?php
/**
 * Plugin Name: Something Historic App API
 * Description: One small REST endpoint that hands the Something Historic mobile app all stories, blog posts, museums, cities and castles in one download, so the app can work offline.
 * Version:     1.0.0
 * Author:      Something Historic
 * Text Domain: sh-app-api
 * Requires PHP: 7.4
 *
 * Endpoints:
 *   GET /wp-json/sh-app/v1/version            → { version, languages }
 *   GET /wp-json/sh-app/v1/bundle?lang=en|ur  → everything the app shows, for one language
 *
 * Works on its own; uses sh-stories, sh-museums, sh-cities, sh-castles and
 * Polylang when they are active and simply leaves their sections empty when not.
 *
 * @package SH_App_API
 */

defined( 'ABSPATH' ) || exit;

final class SH_App_API {

	const NS          = 'sh-app/v1';
	const VERSION_KEY = 'sh_app_api_version';
	const CACHE_TTL   = DAY_IN_SECONDS;

	/** Post types whose changes bump the content version. */
	const TYPES = array( 'post', 'episode', 'museum', 'sh_city', 'sh_castle' );

	/** Taxonomies whose changes bump the content version. */
	const TAXONOMIES = array( 'category', 'empire', 'series', 'museum_type', 'museum_country', 'sh_city_region', 'sh_castle_region' );

	public static function init() {
		add_action( 'rest_api_init', array( __CLASS__, 'routes' ) );
		add_action( 'save_post', array( __CLASS__, 'on_save_post' ), 10, 2 );
		add_action( 'deleted_post', array( __CLASS__, 'bump' ) );
		add_action( 'transition_post_status', array( __CLASS__, 'on_status' ), 10, 3 );
		foreach ( array( 'created_term', 'edited_term', 'delete_term' ) as $hook ) {
			add_action( $hook, array( __CLASS__, 'on_term' ), 10, 3 );
		}
	}

	/* ------------------------------------------------------------------ */
	/* Versioning                                                          */
	/* ------------------------------------------------------------------ */

	public static function version() {
		$version = get_option( self::VERSION_KEY );
		if ( ! $version ) {
			$version = (string) time();
			update_option( self::VERSION_KEY, $version, false );
		}
		return (string) $version;
	}

	public static function bump() {
		update_option( self::VERSION_KEY, (string) time(), false );
	}

	public static function on_save_post( $post_id, $post ) {
		if ( wp_is_post_revision( $post_id ) || ! in_array( $post->post_type, self::TYPES, true ) ) {
			return;
		}
		self::bump();
	}

	public static function on_status( $new, $old, $post ) {
		if ( $new !== $old && in_array( $post->post_type, self::TYPES, true ) ) {
			self::bump();
		}
	}

	public static function on_term( $term_id, $tt_id, $taxonomy ) {
		if ( in_array( $taxonomy, self::TAXONOMIES, true ) ) {
			self::bump();
		}
	}

	/* ------------------------------------------------------------------ */
	/* Routes                                                              */
	/* ------------------------------------------------------------------ */

	public static function routes() {
		register_rest_route(
			self::NS,
			'/version',
			array(
				'methods'             => 'GET',
				'permission_callback' => '__return_true',
				'callback'            => function () {
					return rest_ensure_response(
						array(
							'version'   => self::version(),
							'languages' => self::languages(),
						)
					);
				},
			)
		);

		register_rest_route(
			self::NS,
			'/bundle',
			array(
				'methods'             => 'GET',
				'permission_callback' => '__return_true',
				'args'                => array(
					'lang' => array(
						'type'              => 'string',
						'default'           => 'en',
						'sanitize_callback' => 'sanitize_key',
					),
				),
				'callback'            => array( __CLASS__, 'bundle_response' ),
			)
		);
	}

	public static function languages() {
		if ( function_exists( 'pll_languages_list' ) ) {
			$list = pll_languages_list( array( 'fields' => 'slug' ) );
			if ( $list ) {
				return array_values( $list );
			}
		}
		return array( 'en' );
	}

	public static function bundle_response( WP_REST_Request $request ) {
		$languages = self::languages();
		$lang      = $request->get_param( 'lang' );
		if ( ! in_array( $lang, $languages, true ) ) {
			$lang = $languages[0];
		}

		$version = self::version();
		$key     = 'sh_app_bundle_' . $lang;
		$cached  = get_transient( $key );
		if ( is_array( $cached ) && isset( $cached['version'] ) && $cached['version'] === $version ) {
			$data = $cached;
		} else {
			$data = self::bundle( $lang, $version );
			set_transient( $key, $data, self::CACHE_TTL );
		}

		$response = rest_ensure_response( $data );
		$response->header( 'Cache-Control', 'public, max-age=300' );
		return $response;
	}

	/* ------------------------------------------------------------------ */
	/* Bundle                                                              */
	/* ------------------------------------------------------------------ */

	public static function bundle( $lang, $version ) {
		return array(
			'version'          => $version,
			'generated'        => gmdate( 'c' ),
			'lang'             => $lang,
			'site'             => array(
				'name' => wp_specialchars_decode( get_bloginfo( 'name' ), ENT_QUOTES ),
				'url'  => home_url( '/' ),
			),
			'empires'          => self::terms( 'empire', $lang, array( __CLASS__, 'empire_extra' ) ),
			'series'           => self::terms( 'series', $lang, array( __CLASS__, 'series_extra' ) ),
			'episodes'         => self::posts( 'episode', $lang, array( __CLASS__, 'episode_extra' ) ),
			'posts'            => self::posts( 'post', $lang, array( __CLASS__, 'post_extra' ) ),
			'museums'          => self::posts( 'museum', $lang, array( __CLASS__, 'museum_extra' ) ),
			'museum_types'     => self::terms( 'museum_type', $lang ),
			'museum_countries' => self::terms( 'museum_country', $lang ),
			'cities'           => self::posts( 'sh_city', $lang, array( __CLASS__, 'city_extra' ) ),
			'city_regions'     => self::terms( 'sh_city_region', $lang, array( __CLASS__, 'city_region_extra' ) ),
			'castles'          => self::posts( 'sh_castle', $lang, array( __CLASS__, 'castle_extra' ) ),
			'castle_regions'   => self::terms( 'sh_castle_region', $lang, array( __CLASS__, 'castle_region_extra' ) ),
		);
	}

	private static function lang_args( $lang ) {
		return function_exists( 'pll_languages_list' ) ? array( 'lang' => $lang ) : array();
	}

	private static function text( $value ) {
		return trim( html_entity_decode( wp_strip_all_tags( (string) $value ), ENT_QUOTES, 'UTF-8' ) );
	}

	private static function image( $attachment_id, $size = 'large' ) {
		$attachment_id = (int) $attachment_id;
		if ( ! $attachment_id ) {
			return '';
		}
		$url = wp_get_attachment_image_url( $attachment_id, $size );
		return $url ? $url : '';
	}

	private static function lines( $value ) {
		$lines = preg_split( '/\r\n|\r|\n/', (string) $value );
		return array_values( array_filter( array_map( 'trim', $lines ) ) );
	}

	private static function timeline( $value ) {
		$out = array();
		foreach ( self::lines( $value ) as $line ) {
			$parts = array_map( 'trim', explode( '|', $line, 2 ) );
			$out[] = isset( $parts[1] ) ? array( $parts[0], $parts[1] ) : array( '', $parts[0] );
		}
		return $out;
	}

	private static function term_ids( $post_id, $taxonomy ) {
		$terms = get_the_terms( $post_id, $taxonomy );
		if ( ! $terms || is_wp_error( $terms ) ) {
			return array();
		}
		return array_map( 'intval', wp_list_pluck( $terms, 'term_id' ) );
	}

	private static function content_html( $post ) {
		$html = $post->post_content;
		if ( function_exists( 'do_blocks' ) ) {
			$html = do_blocks( $html );
		}
		$html = strip_shortcodes( $html );
		$html = wptexturize( wpautop( $html ) );
		// Drop scripts, styles and embeds the app cannot use.
		$html = preg_replace( '#<(script|style|iframe|noscript)[^>]*>.*?</\1>#is', '', $html );
		return trim( $html );
	}

	private static function reading_minutes( $post ) {
		if ( class_exists( 'SH_Stories_Reading_Time' ) && method_exists( 'SH_Stories_Reading_Time', 'minutes' ) ) {
			return (int) SH_Stories_Reading_Time::minutes( $post );
		}
		$text  = wp_strip_all_tags( $post->post_content );
		$words = preg_match_all( '/[\p{L}\p{N}]+/u', $text );
		return max( 1, (int) ceil( $words / 200 ) );
	}

	private static function translations_of_post( $post_id ) {
		return function_exists( 'pll_get_post_translations' ) ? array_map( 'intval', pll_get_post_translations( $post_id ) ) : new stdClass();
	}

	private static function translations_of_term( $term_id ) {
		return function_exists( 'pll_get_term_translations' ) ? array_map( 'intval', pll_get_term_translations( $term_id ) ) : new stdClass();
	}

	/**
	 * All published posts of one type in one language.
	 */
	private static function posts( $type, $lang, $extra = null ) {
		if ( ! post_type_exists( $type ) ) {
			return array();
		}
		$posts = get_posts(
			array_merge(
				array(
					'post_type'        => $type,
					'post_status'      => 'publish',
					'posts_per_page'   => -1,
					'orderby'          => 'date',
					'order'            => 'DESC',
					'suppress_filters' => false,
					'no_found_rows'    => true,
				),
				self::lang_args( $lang )
			)
		);

		$out = array();
		foreach ( $posts as $post ) {
			$item = array(
				'id'           => (int) $post->ID,
				'slug'         => $post->post_name,
				'title'        => self::text( get_the_title( $post ) ),
				'excerpt'      => self::text( has_excerpt( $post ) ? $post->post_excerpt : wp_trim_words( $post->post_content, 40 ) ),
				'content'      => self::content_html( $post ),
				'date'         => get_post_time( 'c', true, $post ),
				'modified'     => get_post_modified_time( 'c', true, $post ),
				'image'        => (string) get_the_post_thumbnail_url( $post, 'large' ),
				'link'         => get_permalink( $post ),
				'translations' => self::translations_of_post( $post->ID ),
			);
			if ( $extra ) {
				$item = array_merge( $item, call_user_func( $extra, $post ) );
			}
			$out[] = $item;
		}
		return $out;
	}

	/**
	 * All terms of one taxonomy in one language.
	 */
	private static function terms( $taxonomy, $lang, $extra = null ) {
		if ( ! taxonomy_exists( $taxonomy ) ) {
			return array();
		}
		$terms = get_terms(
			array_merge(
				array(
					'taxonomy'   => $taxonomy,
					'hide_empty' => false,
				),
				self::lang_args( $lang )
			)
		);
		if ( is_wp_error( $terms ) ) {
			return array();
		}

		$out = array();
		foreach ( $terms as $term ) {
			$item = array(
				'id'           => (int) $term->term_id,
				'slug'         => $term->slug,
				'name'         => self::text( $term->name ),
				'description'  => self::text( $term->description ),
				'parent'       => (int) $term->parent,
				'count'        => (int) $term->count,
				'link'         => (string) get_term_link( $term ),
				'translations' => self::translations_of_term( $term->term_id ),
			);
			if ( $extra ) {
				$item = array_merge( $item, call_user_func( $extra, $term ) );
			}
			$out[] = $item;
		}
		return $out;
	}

	/* ------------------------------------------------------------------ */
	/* Per-type fields                                                     */
	/* ------------------------------------------------------------------ */

	public static function empire_extra( $term ) {
		return array(
			'period' => (string) get_term_meta( $term->term_id, 'sh_period', true ),
			'intro'  => (string) get_term_meta( $term->term_id, 'sh_intro', true ),
			'image'  => self::image( get_term_meta( $term->term_id, 'sh_cover_id', true ) ),
			'map'    => self::image( get_term_meta( $term->term_id, 'sh_map_id', true ) ),
		);
	}

	public static function series_extra( $term ) {
		$status = (string) get_term_meta( $term->term_id, 'sh_status', true );
		return array(
			'empire' => (int) get_term_meta( $term->term_id, 'sh_empire', true ),
			'intro'  => (string) get_term_meta( $term->term_id, 'sh_intro', true ),
			'image'  => self::image( get_term_meta( $term->term_id, 'sh_cover_id', true ) ),
			'total'  => (int) get_term_meta( $term->term_id, 'sh_total_episodes', true ),
			'status' => $status ? $status : 'ongoing',
		);
	}

	public static function episode_extra( $post ) {
		$series = self::term_ids( $post->ID, 'series' );
		$empire = self::term_ids( $post->ID, 'empire' );
		return array(
			'series'          => $series ? $series[0] : 0,
			'empire'          => $empire ? $empire[0] : 0,
			'number'          => (int) get_post_meta( $post->ID, 'sh_episode_number', true ),
			'next_release'    => (string) get_post_meta( $post->ID, 'sh_next_release', true ),
			'reading_minutes' => self::reading_minutes( $post ),
		);
	}

	public static function post_extra( $post ) {
		$categories = get_the_category( $post->ID );
		return array(
			'categories'      => array_values( array_map( array( __CLASS__, 'text' ), wp_list_pluck( $categories, 'name' ) ) ),
			'reading_minutes' => self::reading_minutes( $post ),
		);
	}

	public static function museum_extra( $post ) {
		$m       = function ( $key ) use ( $post ) {
			return (string) get_post_meta( $post->ID, 'sh_museum_' . $key, true );
		};
		$empires = function_exists( 'sh_museums_id_list' ) ? sh_museums_id_list( $m( 'empires' ) ) : array_filter( array_map( 'intval', explode( ',', $m( 'empires' ) ) ) );
		return array(
			'type'    => self::term_ids( $post->ID, 'museum_type' ),
			'country' => self::term_ids( $post->ID, 'museum_country' ),
			'meta'    => array(
				'tagline'    => $m( 'tagline' ),
				'city'       => $m( 'city' ),
				'address'    => $m( 'address' ),
				'founded'    => $m( 'founded' ),
				'hours'      => $m( 'hours' ),
				'tickets'    => $m( 'tickets' ),
				'website'    => $m( 'website' ),
				'lat'        => $m( 'lat' ),
				'lng'        => $m( 'lng' ),
				'highlights' => self::lines( $m( 'highlights' ) ),
				'featured'   => (bool) $m( 'featured' ),
				'empires'    => array_values( array_map( 'intval', (array) $empires ) ),
			),
		);
	}

	public static function city_extra( $post ) {
		$m = function ( $key ) use ( $post ) {
			return (string) get_post_meta( $post->ID, '_shc_' . $key, true );
		};
		return array(
			'region' => self::term_ids( $post->ID, 'sh_city_region' ),
			'meta'   => array(
				'tagline'      => $m( 'tagline' ),
				'location'     => $m( 'location' ),
				'founded'      => $m( 'founded' ),
				'civilization' => $m( 'civilization' ),
				'year'         => $m( 'year' ),
				'status'       => $m( 'status' ),
				'unesco'       => $m( 'unesco' ),
				'lat'          => $m( 'lat' ),
				'lng'          => $m( 'lng' ),
				'highlights'   => self::lines( $m( 'highlights' ) ),
				'timeline'     => self::timeline( $m( 'timeline' ) ),
				'featured'     => (bool) $m( 'featured' ),
			),
		);
	}

	public static function castle_extra( $post ) {
		$m = function ( $key ) use ( $post ) {
			return (string) get_post_meta( $post->ID, '_shk_' . $key, true );
		};
		return array(
			'region' => self::term_ids( $post->ID, 'sh_castle_region' ),
			'meta'   => array(
				'tagline'    => $m( 'tagline' ),
				'location'   => $m( 'location' ),
				'built'      => $m( 'built' ),
				'builder'    => $m( 'builder' ),
				'type'       => $m( 'type' ),
				'year'       => $m( 'year' ),
				'status'     => $m( 'status' ),
				'unesco'     => $m( 'unesco' ),
				'lat'        => $m( 'lat' ),
				'lng'        => $m( 'lng' ),
				'highlights' => self::lines( $m( 'highlights' ) ),
				'timeline'   => self::timeline( $m( 'timeline' ) ),
				'featured'   => (bool) $m( 'featured' ),
			),
		);
	}

	public static function city_region_extra( $term ) {
		return array( 'image' => self::image( get_term_meta( $term->term_id, '_shc_cover', true ) ) );
	}

	public static function castle_region_extra( $term ) {
		return array( 'image' => self::image( get_term_meta( $term->term_id, '_shk_cover', true ) ) );
	}
}

SH_App_API::init();
