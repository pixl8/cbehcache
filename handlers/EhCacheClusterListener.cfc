/**
 * Handler for receiving cache events from the cluster
 *
 *
 */
component {

	property name="cachebox" inject="cachebox";

	private void function set( event, rc, prc, cacheName="", objectKey="", object="" ) {
		if ( cachebox.cacheExists( arguments.cacheName ) ) {
			var cache = cachebox.getCache( arguments.cacheName );

			cache.set(
				  propagate = false
				, objectKey = arguments.objectKey
				, object    = arguments.object
			);
		}

	}

	private void function clearall( event, rc, prc, cacheName="" ) {
		if ( cachebox.cacheExists( arguments.cacheName ) ) {
			var cache = cachebox.getCache( arguments.cacheName );

			systemoutput( "clearall :)" )

			cache.clearall( propagate=false );
		}
	}

	private void function clear( event, rc, prc, cacheName="", objectKey="" ) {
		var cache = cachebox.getCache( arguments.cacheName );

		cache.clear(
			  propagate = false
			, objectKey = arguments.objectKey
		);
	}

}